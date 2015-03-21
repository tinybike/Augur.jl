# Save data to .jld file
function save_data(sim::Simulation,
                   results::Dict,
                   ltr::Range;
                   parametrize::Bool=false)
    sim_data = (String => Any)[
        "sim" => sim,
        "trajectories" => results["trajectories"],
        "parametrize" => parametrize,
        "liar_threshold" => convert(Array, ltr),
        "iterate" => results["iterate"],
    ]
    @inbounds for algo in sim.ALGOS
        sim_data[algo] = Dict{String,Array}()
        for s in sim.STATISTICS
            for m in [sim.METRICS, "components"]
                metric = (s == "mean") ? m : m * "_std"
                sim_data[algo][metric] = results[algo][s][m]
            end
        end
    end
    filename = "data/sim_" * repr(now()) * ".jld"
    jldopen(filename, "w") do file
        write(file, "sim_data", sim_data)
    end
    println("Data saved to ", filename)
    return sim_data
end

# Load data from .jld file
function load_data(datafile::String)
    jldopen(datafile, "r") do file
        read(file, "sim_data")
    end
end

function save_time_elapsed(time_elapsed::Dict{Symbol,Vector{Float64}},
                           timestamp::String,
                           param::String,
                           sim::Simulation,
                           iterations::Int,
                           param_range::Range)
    filename = "data/time_" * param * "_" * timestamp * ".jld"
    jldopen(filename, "w") do file
        write(file, "time_elapsed", time_elapsed)
        write(file, "sim", sim)
        write(file, "param", param)
        write(file, "iterations", iterations)
        write(file, "param_range", param_range)
        write(file, "timestamp", timestamp)
    end
    println("Data saved to ", filename)
end

function load_time_elapsed(datafile::String)
    jldopen(datafile, "r") do file
        time_elapsed = read(file, "time_elapsed")
        sim = read(file, "sim")
        param = read(file, "param")
        iterations = read(file, "iterations")
        param_range = read(file, "param_range")
        timestamp = read(file, "timestamp")
        (time_elapsed, sim, param, iterations, param_range, timestamp)
    end
end
