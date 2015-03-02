@everywhere using Simulator

function run_simulations(ltr::Range)
    println("Running simulations...")

    # Run parallel simulations
    sim = Simulation()
    raw::Array{Dict{String,Any},1} = @sync @parallel (vcat) for lt in ltr
        println(round(lt * 100, 2), "% random")
        sim.LIAR_THRESHOLD = lt
        simulate(sim)
    end

    # Set up final results dictionary
    gridrows = length(ltr)
    results = Dict{String,Any}()
    @inbounds for algo in sim.ALGOS
        results[algo] = Dict{String,Dict}()
        @inbounds for s in sim.STATISTICS
            results[algo][s] = Dict{String,Array}()
            @inbounds for m in sim.METRICS
                results[algo][s][m] = zeros(gridrows)
            end
        end
    end

    # Sort results using liar_threshold values
    @inbounds for (row, liar_threshold) in enumerate(ltr)
        i = 1
        matched = Dict{String,Dict}()
        @inbounds for i = 1:gridrows
            if raw[i]["liar_threshold"] == liar_threshold
                matched = splice!(raw, i)
                break
            end
        end
        results["iterate"] = matched["iterate"]
        @inbounds for algo in sim.ALGOS
            @inbounds for s in sim.STATISTICS
                @inbounds for m in sim.METRICS
                    results[algo][s][m][row,1] = matched[algo][s][m]
                end
            end
        end
    end
    save_data(sim, results, ltr)
end

function save_data(sim::Simulation,
                   results::Dict,
                   ltr::Range;
                   parametrize::Bool=false)
    # Save data to file
    sim_data = (String => Any)[
        "sim" => sim,
        "parametrize" => parametrize,
        "liar_threshold" => convert(Array, ltr),
        "iterate" => results["iterate"],
    ]
    @inbounds for algo in sim.ALGOS
        sim_data[algo] = (String => Array)[
            "liars_bonus" => results[algo]["mean"]["liars_bonus"],
            "beats" => results[algo]["mean"]["beats"],
            "correct" => results[algo]["mean"]["correct"],
            "components" => results[algo]["mean"]["components"],
            "liars_bonus_std" => results[algo]["stderr"]["liars_bonus"],
            "beats_std" => results[algo]["stderr"]["beats"],
            "correct_std" => results[algo]["stderr"]["correct"],
            "components_std" => results[algo]["stderr"]["components"],
        ]
    end
    filename = "data/sim_" * repr(now()) * ".jld"
    jldopen(filename, "w") do file
        write(file, "sim_data", sim_data)
    end
    println("Data saved to ", filename)
    return sim_data
end

function load_data(datafile::String)
    jldopen(datafile, "r") do file
        read(file, "sim_data")
    end
end
