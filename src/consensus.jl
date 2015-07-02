using StatsBase
using Distances
using DataStructures
using HClust
using Clustering

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

function newMean(cmax::ClusterNode)
    weighted = zeros(cmax.numItems, size(cmax.vec, 2))
    for i = 1:cmax.numItems
        weighted[i,:] = cmax.vec[i,:] * cmax.repVec[i]
    end
    vec(sum(weighted, 1) / cmax.rep)
end

function process(clusters::Vector{ClusterNode},
                 numReporters::Int,
                 times::Int,
                 features::Matrix{Float64},
                 rep::Vector{Float64},
                 threshold::Float64)
    mode = nothing
    numInMode = 0
    global best, bestClusters, bestDist
    for i = 1:length(clusters)
        if clusters[i].rep > numInMode
            numInMode = clusters[i].rep
            mode = clusters[i]
        end
    end
    outcomes = vec(mean(features, weights(rep), 1))
    if L2dist(mode.meanVec, outcomes) < bestDist
        bestDist = L2dist(mode.meanVec, outcomes)
        best = mode
        bestClusters = clusters
    end
    #if L2dist(mode.meanVec, outcomes) > 1.07 && times == 1
    #    cluster(features, rep; times=2, threshold=threshold*3)
    if true
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
            repVector[i] = 1 - distMatrix[i] / maximum(distMatrix)
        end
        normalize(repVector)
    end
end

function cluster(features::Matrix{Float64},
                 rep::Vector{Float64};
                 times::Int=1,
                 threshold::Float64=0.50)
    # cluster the rows of the "features" matrix
    #if threshold == 0.50
    #    threshold = log10(size(features, 2)) / 1.77
    #    if threshold == 0
    #        threshold = 0.3
    #    end
    #end
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
            dist = L2dist(vec(features[i,:]), clusters[n].meanVec)
            if dist < shortestDist
                cmax = clusters[n]
                shortestDist = dist
            end
        end
        if cmax != nothing && L2dist(vec(features[i,:]), cmax.meanVec) < threshold
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

function clusterfeck(features::Matrix{Float64},
                     rep::Vector{Float64};
                     threshold::Float64=0.50)
    #if threshold == 0.50
    #    threshold = log10(size(features, 2)) / 1.77
    #    if threshold == 0
    #        threshold = 0.3
    #    end
    #end
    global best, bestDist, bestClusters
    best = nothing
    bestDist = Inf
    bestClusters = nothing
    cluster(features, rep; times=1, threshold=threshold)
end

function wPCA(reports::Matrix{Float64}, rep::Vector{Float64})
    centered = reports .- mean(reports, weights(rep), 1)
    (U, S, Vt) = svd(cov(centered))
    first_loading = U[:,1] / sqrt(sum(U[:,1].^2))
    first_score = centered * first_loading
    (first_loading, first_score)
end

function PCA(reports::Matrix{Float64}, rep::Vector{Float64})
    (first_loading, first_score) = wPCA(reports, rep)
    nc_rankdata(first_score, reports, rep)
end

function nc_rankdata(scores::Vector{Float64},
                     reports::Matrix{Float64},
                     rep::Vector{Float64})
    set1 = scores + abs(minimum(scores))
    set2 = scores - maximum(scores)
    old = vec(rep' * reports)
    rank_old = rankdata(old)
    new1 = rankdata(vec(normalize(set1)' * reports) + 0.01*old)
    new2 = rankdata(vec(normalize(set2)' * reports) + 0.01*old)
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

function update_reputation(clustered::Vector{Int})
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

function hierarchical(sim::Simulation,
                      reports::Matrix{Float64},
                      rep::Vector{Float64})
    centered = reports .- mean(reports, weights(rep), 1)
    dist = pairwise(Euclidean(), centered')
    clustered = cutree(hclust(dist, sim.HIERARCHICAL_LINKAGE);
                       h=sim.HIERARCHICAL_THRESHOLD)
    update_reputation(clustered)
end

function DBSCAN(sim::Simulation,
                reports::Matrix{Float64},
                rep::Vector{Float64})
    centered = reports .- mean(reports, weights(rep), 1)
    dist = pairwise(Euclidean(), centered')
    result = dbscan(dist, sim.DBSCAN_EPSILON, sim.DBSCAN_MINPOINTS)
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

function affinity(reports::Matrix{Float64}, rep::Vector{Float64})
    centered = reports .- mean(reports, weights(rep), 1)
    dist = pairwise(Euclidean(), centered')
    clustered = affinityprop(dist).assignments
    update_reputation(clustered)
end

function consensus(sim::Simulation,
                   reports::Matrix{Float64},
                   rep::Vector{Float64};
                   algo::ASCIIString="clusterfeck")
    (num_reports, num_events) = size(reports)
    reptokens = rep
    rep = normalize(rep)
    # TODO interpolate
    if algo == "clusterfeck"
        nonconform = clusterfeck(reports, rep; threshold=sim.CLUSTERFECK_THRESHOLD)
    elseif algo == "PCA"
        nonconform = PCA(reports, rep)
    elseif algo == "hierarchical"
        nonconform = hierarchical(sim, reports, rep)
    elseif algo == "DBSCAN"
        nonconform = DBSCAN(sim, reports, rep)
    elseif algo == "affinity"
        nonconform = affinity(reports, rep)
    end
    this_rep = normalize(nonconform .* rep / mean(rep))
    updated_rep = sim.ALPHA*this_rep + (1 - sim.ALPHA)*rep
    outcomes_raw = vec(updated_rep' * reports)
    # TODO scaled
    outcomes_adj = zeros(num_events)
    for i = 1:num_events
        outcomes_adj[i] = roundoff(sim, outcomes_raw[i])
    end
    outcomes_final = zeros(num_events)
    # TODO scaled
    for i = 1:num_events
        outcomes_final[i] = outcomes_adj[i]
    end
    certainty = zeros(num_events)
    for i = 1:num_events
        certainty[i] = sum(updated_rep[reports[:,i] .== outcomes_adj[i]])
    end
    consensus_reward = normalize(certainty)
    avg_certainty = mean(certainty)
    
    # Participation
    na_mat = zeros(num_reports, num_events)
    na_mat[isnan(reports)] = 1
    na_mat[reports .== sim.NULL] = 1
    participation_columns = 1 - updated_rep' * na_mat
    participation_rows = 1 - sum(na_mat, 2) / size(na_mat, 2)
    percent_na = 1 - mean(participation_columns)
    na_bonus_reporters = normalize(participation_rows)
    reporter_bonus = na_bonus_reporters.*percent_na + updated_rep.*(1-percent_na)
    na_bonus_events = normalize(participation_columns)
    author_bonus = na_bonus_events*percent_na + consensus_reward*(1-percent_na)
    (Symbol => Array{Float64})[
        :reports => reports,
        :initial_rep => rep,
        :updated_rep => updated_rep,
        :participation => participation_rows,
        :reporter_bonus => reporter_bonus,
        :nonconformity => nonconform,
        :outcomes_raw => outcomes_raw,
        :certainty => certainty,
        :outcomes_final => outcomes_final,
    ]
end
