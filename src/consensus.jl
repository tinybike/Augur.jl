using StatsBase
using DataStructures
using Distances
using HClust
using Clustering

# TODO move these to Simulator type
NO = 1.0
YES = 2.0
BAD = 1.5
NA = 0.0
CATCH_TOLERANCE = 0.1

type ClusterNode
    vec::Matrix{Float64}
    numItems::Int
    meanVec::Vector{Float64}
    rep::Float64
    repVec::Vector{Float64}
    reporterIndexVec::Vector{Int}
    dist::Float64
    ClusterNode(vec; numItems=0,
                     meanVec=nothing,
                     rep=0,
                     repVec=nothing,
                     reporterIndexVec=nothing,
                     dist=-1) =
        new(vec, numItems, meanVec, rep, repVec, reporterIndexVec, dist)
end

function roundoff(x)
    if x < BAD - CATCH_TOLERANCE
        NO
    elseif x > BAD + CATCH_TOLERANCE
        YES
    else
        BAD
    end
end

normalize{T<:Real}(v::Vector{T}) = vec(v) / sum(v)

normalize{T<:Real}(v::Matrix{T}) = normalize(vec(v))

L2dist(v1, v2) = sqrt(sum((vec(v1) - vec(v2)).^2))

function newMean(cmax)
    weighted = zeros(cmax.numItems, size(cmax.vec, 2))
    for i = 1:cmax.numItems
        weighted[i,:] = cmax.vec[i,:] * cmax.repVec[i]
    end
    vec(sum(weighted, 1) / cmax.rep)
end

function process(clusters, numReporters, times, features, rep, threshold)
    mode = nothing
    numInMode = 0
    global best, bestClusters, bestDist
    for i = 1:length(clusters)
        if clusters[i].rep > numInMode
            numInMode = clusters[i].rep
            mode = clusters[i]
        end
    end
    outcomes = mean(features, weights(rep), 1)'
    if L2dist(mode.meanVec, outcomes) < bestDist
        bestDist = L2dist(mode.meanVec, outcomes)
        best = mode
        bestClusters = clusters
    end
    if L2dist(mode.meanVec, outcomes) > 1.07 && times == 1
        cluster(features, rep; times=2, threshold=threshold*3)
    else
        for i = 1:length(bestClusters)
            bestClusters[i].dist = L2dist(best.meanVec, bestClusters[i].meanVec)
        end
        distMatrix = zeros(numReporters)
        for j = 1:length(bestClusters)
            for i = 1:bestClusters[j].numItems
                distMatrix[bestClusters[j].reporterIndexVec[i]] = bestClusters[j].dist
            end
        end
        repVector = zeros(numReporters)
        for i = 1:length(distMatrix)
            repVector[i] = 1 - distMatrix[i] / (maximum(distMatrix) + 0.00000001)
        end
        normalize(repVector)
    end
end

function cluster(features, rep; times=1, threshold=0.50, distance=L2dist)
    # cluster the rows of the "features" matrix
    if threshold == 0.50
        threshold = log10(size(features, 2)) / 1.77
    end
    clusters = ClusterNode[]
    for i = 1:length(rep)
        if rep[i] == 0.0
            rep[i] = 0.00001
        end
    end
    for i = 1:size(features, 1)
        # cmax: most similar cluster
        cmax = nothing
        shortestDist = Inf
        for n = 1:length(clusters)
            dist = L2dist(features[i,:], clusters[n].meanVec)
            if dist < shortestDist
                cmax = clusters[n]
                shortestDist = dist
            end
        end
        if cmax != nothing && L2dist(features[i,:], cmax.meanVec) < threshold
            cmax.vec = vcat(cmax.vec, features[i,:])
            cmax.numItems += 1
            cmax.rep += rep[i]
            push!(cmax.repVec, rep[i])
            cmax.meanVec = newMean(cmax)
            push!(cmax.reporterIndexVec, i)
        else
            if ~any(isnan(features[i,:]))
                push!(clusters, ClusterNode(features[i,:]; numItems=1,
                                                           meanVec=vec(features[i,:]),
                                                           rep=rep[i],
                                                           repVec=[rep[i]],
                                                           reporterIndexVec=[i]))
            end
        end
    end
    process(clusters, size(features, 1), times, features, rep, threshold)
end

function clusterfeck(features, rep; threshold=0.50)
    if threshold == 0.50
        threshold = log10(size(features, 2)) / 1.77
    end
    global best, bestDist, bestClusters
    best = nothing
    bestDist = Inf
    bestClusters = nothing
    cluster(features, rep; times=1, threshold=threshold)
end

function wPCA(reports, rep)
    centered = reports .- mean(reports, weights(rep), 1)
    (U, S, Vt) = svd(cov(centered))
    first_loading = U[:,1] / sqrt(sum(U[:,1].^2))
    first_score = centered * first_loading
    (first_loading, first_score)
end

function PCA(reports, rep)
    (first_loading, first_score) = wPCA(reports, rep)
    nonconformity(first_score, reports, rep)
end

function nonconformity_rank(scores, reports, rep)
    set1 = scores + abs(minimum(scores))
    set2 = scores - maximum(scores)
    old = vec(rep' * reports)
    # TODO rankdata
    rank_old = rank(old)
    new1 = rank(normalize(set1)' * reports + 0.01*old)
    new2 = rank(normalize(set2)' * reports + 0.01*old)
    ref_ind = sum(abs(new1 - rank_old)) - sum(abs(new2 - rank_old))
    if ref_ind == 0
        nonconformity(scores, reports, rep)
    else
        (ref_ind < 0) ? set1 : set2
    end
end

function nonconformity(scores, reports, rep)
    set1 = scores + abs(minimum(scores))
    set2 = scores - maximum(scores)
    old = rep' * reports
    new1 = normalize(set1)' * reports
    new2 = normalize(set2)' * reports
    ref_ind = sum((new1 - old).^2) - sum((new2 - old).^2)
    (ref_ind <= 0) ? set1 : set2
end

most_common(c::Accumulator) = most_common(c, length(c))
most_common(c::Accumulator, k::Int) = select!(collect(c), 1:k, by=kv->kv[2], rev=true)

function hierarchical(reports, rep; threshold=0.50)
    centered = reports .- mean(reports, weights(rep), 1)
    dist = pairwise(Euclidean(), centered')
    clustered = cutree(hclust(dist, :single); h=threshold)
    counts = most_common(counter(clustered))
    new_rep = Dict{Int,Int}()
    for c in counts
        new_rep[c[1]] = c[2]
    end
    new_rep_list = Int[]
    for c in clustered
        push!(new_rep_list, new_rep[c])
    end
    new_rep_list .-= minimum(new_rep_list)
    new_rep_list / sum(new_rep_list)
end

function DBSCAN(reports, rep; eps=0.5, minpts=1)
    centered = reports .- mean(reports, weights(rep), 1)
    dist = pairwise(Euclidean(), centered')
    result = dbscan(dist, eps, minpts)
    new_rep = Dict{Int,Int}()
    for (i, c) in enumerate(result.counts)
        new_rep[i] = c
    end
    new_rep_list = Int[]
    for c in result.assignments
        push!(new_rep_list, new_rep[c])
    end
    new_rep_list .-= minimum(new_rep_list)
    new_rep_list / sum(new_rep_list)
end

function consensus(reports, rep; algo="clusterfeck", alpha=0.1)
    (num_reports, num_events) = size(reports)
    reptokens = rep
    rep = normalize(rep)
    # TODO interpolate
    if algo == "clusterfeck"
        nc = clusterfeck(reports, rep)
    elseif algo == "PCA"
        nc = PCA(reports, rep)
    elseif algo == "hierarchical"
        nc = hierarchical(reports, rep; threshold=0.5)
    elseif algo == "DBSCAN"
        nc = DBSCAN(reports, rep; eps=0.5, minpts=1)
    end
    this_rep = normalize(nc .* rep / mean(rep))
    smooth_rep = alpha*this_rep + (1-alpha)*rep
    outcomes_raw = vec(smooth_rep' * reports)
    # TODO scaled
    outcomes_adj = zeros(num_events)
    for i = 1:num_events
        outcomes_adj[i] = roundoff(outcomes_raw[i])
    end
    outcomes_final = zeros(num_events)
    # TODO scaled
    for i = 1:num_events
        outcomes_final[i] = outcomes_adj[i]
    end
    certainty = zeros(num_events)
    for i = 1:num_events
        certainty[i] = sum(smooth_rep[reports[:,i] .== outcomes_adj[i]])
    end
    consensus_reward = normalize(certainty)
    avg_certainty = mean(certainty)
    
    # Participation
    na_mat = zeros(num_reports, num_events)
    na_mat[isnan(reports)] = 1
    na_mat[reports .== NA] = 1

    participation_columns = 1 - smooth_rep' * na_mat
    participation_rows = 1 - sum(na_mat, 2) / size(na_mat, 2)

    percent_na = 1 - mean(participation_columns)
    na_bonus_reporters = normalize(participation_rows)

    reporter_bonus = na_bonus_reporters.*percent_na + smooth_rep.*(1-percent_na)

    na_bonus_events = normalize(participation_columns)
    author_bonus = na_bonus_events*percent_na + consensus_reward*(1-percent_na)
    [
        :original => reports,
        :filled => reports,
        :agents => [
            :old_rep => rep,
            :this_rep => this_rep,
            :smooth_rep => smooth_rep,
            :na_row => sum(na_mat, 2),
            :participation_rows => participation_rows,
            :relative_part => na_bonus_reporters,
            :reporter_bonus => reporter_bonus,
        ],
        :events => [
            :outcomes_raw => outcomes_raw,
            :consensus_reward => consensus_reward,
            :certainty => certainty,
            :nas_filled => sum(na_mat, 1),
            :participation_columns => participation_columns,
            :author_bonus => author_bonus,
            :outcomes_final => outcomes_final,
        ],
        :participation => 1 - percent_na,
        :avg_certainty => avg_certainty,
    ]
end

# reports = [ 2.000000  2.000000  1.000000  1.000000
#             2.000000  1.000000  1.000000  1.000000
#             2.000000  2.000000  1.000000  1.000000
#             2.000000  2.000000  2.000000  1.000000
#             1.000000  1.000000  2.000000  2.000000
#             1.000000  1.000000  2.000000  2.000000 ]

# rep = convert(Vector{Float64}, [166666, 166666, 166666, 166666, 166666, 166666])

# results = consensus(reports, rep; algo="DBSCAN")
# display(results)
# println("")
# display(results[:agents])
# println("")
# display(results[:events])
# println("")
