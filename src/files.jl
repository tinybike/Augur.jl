# Save data to .jld file
function save_data(sim::Simulation,
                   results::Dict,
                   ltr::Range;
                   parametrize::Bool=false)
    sim_data = (String => Any)[
        "sim" => sim,
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
