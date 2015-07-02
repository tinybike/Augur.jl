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

L2dist(v::Vector{Float64}, u::Vector{Float64}) = sqrt(sum((v - u).^2))

most_common(c::Accumulator) = most_common(c, length(c))

most_common(c::Accumulator, k::Int) = select!(collect(c), 1:k, by=kv->kv[2], rev=true)

function rankdata(v::Vector{Float64})
    n = length(v)
    ivec = sortperm(v)
    svec = [v[rank] for rank in ivec]
    sumranks = 0
    dupcount = 0
    newarray = zeros(n)
    for i = 1:n
        sumranks += i
        dupcount += 1
        if i == n || svec[i] != svec[i+1]
            averank = sumranks / dupcount + 1
            for j = (i-dupcount+1):i
                newarray[ivec[j]] = averank
            end
            sumranks = 0
            dupcount = 0
        end
    end
    return newarray
end
