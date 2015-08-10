using Augur
using Distances
using Clustering
using StatsBase

best = nothing
bestDist = Inf
bestClusters = nothing

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

L2dist(v::Vector{Float64}, u::Vector{Float64}) = sqrt(sum((v - u).^2))

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
    if threshold == 0.50
        threshold = log10(size(features, 2)) / 1.77
        if threshold == 0
            threshold = 0.3
        end
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

function cflash(features::Matrix{Float64},
                rep::Vector{Float64};
                threshold::Float64=0.50)
    if threshold == 0.50
        threshold = log10(size(features, 2)) / 1.77
        if threshold == 0
            threshold = 0.3
        end
    end
    global best, bestDist, bestClusters
    best = nothing
    bestDist = Inf
    bestClusters = nothing
    cluster(features, rep; times=1, threshold=threshold)
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

function affinity(sim::Simulation,
                  reports::Matrix{Float64},
                  rep::Vector{Float64})
    centered = reports .- mean(reports, weights(rep), 1)
    dist = pairwise(Euclidean(), centered')
    clustered = affinityprop(dist; damp=sim.AFFINITY_DAMPENING).assignments
    update_reputation(clustered)
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
