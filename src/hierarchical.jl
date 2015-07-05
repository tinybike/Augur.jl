using Augur
using HClust
using Distances

function hierarchical(sim::Simulation,
                      reports::Matrix{Float64},
                      rep::Vector{Float64})
    centered = reports .- mean(reports, weights(rep), 1)
    dist = pairwise(Euclidean(), centered')
    clustered = cutree(hclust(dist, sim.HIERARCHICAL_LINKAGE);
                       h=sim.HIERARCHICAL_THRESHOLD)
    update_reputation(clustered)
end
