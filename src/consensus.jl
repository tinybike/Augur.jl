using Augur
using StatsBase
using DataStructures

function roundoff(sim::Simulation, x::Float64)
    if x < sim.BAD - sim.CATCH_TOLERANCE
        sim.NO
    elseif x > sim.BAD + sim.CATCH_TOLERANCE
        sim.YES
    else
        sim.BAD
    end
end

normalize{T<:Real}(v::Vector{T}) = vec(v) / sum(v)

normalize{T<:Real}(v::Matrix{T}) = normalize(vec(v))

most_common(c::Accumulator) = most_common(c, length(c))

most_common(c::Accumulator, k::Int) = select!(collect(c), 1:k, by=kv->kv[2], rev=true)

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

function consensus(sim::Simulation,
                   reports::Matrix{Float64},
                   rep::Vector{Float64};
                   algo::ASCIIString="cflash")
    (num_reports, num_events) = size(reports)
    reptokens = rep
    rep = normalize(rep)
    # TODO interpolate
    if algo == "cflash"
        nonconform = cflash(reports, rep; threshold=sim.CLUSTERFECK_THRESHOLD)
    elseif algo == "PCA"
        nonconform = PCA(reports, rep)
    elseif algo == "hierarchical"
        nonconform = hierarchical(sim, reports, rep)
    elseif algo == "DBSCAN"
        nonconform = DBSCAN(sim, reports, rep)
    elseif algo == "affinity"
        nonconform = affinity(sim, reports, rep)
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
