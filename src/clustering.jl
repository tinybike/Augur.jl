using Augur
using Distances
using Clustering

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
