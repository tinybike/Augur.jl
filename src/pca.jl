using Augur
using StatsBase

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
    rank_old = tiedrank(old)
    new1 = tiedrank(vec(normalize(set1)' * reports) + 0.01*old)
    new2 = tiedrank(vec(normalize(set2)' * reports) + 0.01*old)
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
