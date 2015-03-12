@pyimport pyconsensus

function simulate(sim::Simulation)
    iterate = (Int64)[]
    i = 1
    reporters = []
    raw_data = (String => Any)[ "sim" => sim ]
    @inbounds for algo in sim.ALGOS
        raw_data[algo] = Dict{String,Any}()
        for m in [sim.METRICS, "components"]
            raw_data[algo][m] = Dict{Int,Vector{Float64}}()
            for t in 1:sim.TIMESTEPS
                raw_data[algo][m][t] = (Float64)[]
            end
        end
    end
    @inbounds while i <= sim.ITERMAX
        A = Dict{String,Any}()
        for algo in sim.ALGOS
            A[algo] = Dict{String,Any}()
            metrics = Dict{Symbol,Float64}()

            # Create reporters and assign each reporter a label
            reporters = create_reporters(sim)

            # Simulate over #TIMESTEPS consensus resolutions:
            #   - The previous (smoothed) reputation is used as an input to
            #     the next time step
            #   - Reporters' labels (true, liar, etc.) do not change
            #   - Correct answers and reports are generated fresh at each
            #     time step
            data = Dict{Symbol,Any}()
            for t = 1:sim.TIMESTEPS
                data = generate_data(sim, reporters)
                
                # Assign/update reputation
                if t == 1
                    reputation = normalize(
                        (sim.REP_RAND) ? rand(sim.REP_RANGE, sim.REPORTERS) : ones(sim.REPORTERS)
                    )
                else
                    reputation = A[algo]["agents"]["smooth_rep"]
                end

                if algo == "coskewness"

                    # Per-user coskewness contribution
                    contrib = contraction(data[:reports]', 3; standardize=true, bias=0)
                    data[:aux] = [ :coskew => contrib / sum(contrib) ]

                elseif algo == "cokurtosis"

                    # Per-user cokurtosis contribution
                    contrib = contraction(data[:reports]', 4; standardize=true, bias=0)
                    data[:aux] = [ :cokurt => contrib / sum(contrib) ]

                elseif algo == "FVT+cokurtosis"

                    contrib = contraction(data[:reports]', 4; standardize=true, bias=0)
                    data[:aux] = [ :cokurt => contrib / sum(contrib) ]
                end

                # Use pyconsensus for event resolution
                A[algo] = pyconsensus.Oracle(
                    reports=data[:reports],
                    reputation=reputation,
                    alpha=sim.ALPHA,
                    variance_threshold=sim.VARIANCE_THRESHOLD,
                    aux=data[:aux],
                    beta=sim.BETA,
                    algorithm=algo,
                )[:consensus]()

                # Measure this algorithm's performance
                metrics = compute_metrics(
                    sim,
                    data,
                    A[algo]["events"]["outcomes_final"],
                    reputation,
                    A[algo]["agents"]["smooth_rep"],
                )
                if sim.SAVE_RAW_DATA || t == sim.TIMESTEPS
                    for m in sim.METRICS
                        push!(raw_data[algo][m][t], metrics[symbol(m)])
                    end
                    push!(raw_data[algo]["components"][t], A[algo]["components"])
                end
            end
        end

        push!(iterate, i)
        i += 1
    end
    if sim.SAVE_RAW_DATA
        filename = "data/raw/raw_sim_" * repr(now()) * ".jld"
        jldopen(filename, "w") do file
            write(file, "raw_data", raw_data)
        end
    end

    # Convert raw data into means and standard errors for plotting
    processed_data = (String => Any)[
        "iterate" => iterate,
        "liar_threshold" => sim.LIAR_THRESHOLD,
    ]
    @inbounds for algo in sim.ALGOS
        processed_data[algo] = Dict{String,Dict{String,Float64}}()
        for s in sim.STATISTICS
            processed_data[algo][s] = Dict{String,Float64}()
            sfun = (s == "mean") ? mean : (v) -> std(v) / sim.SQRTN
            for m in [sim.METRICS, "components"]
                processed_data[algo][s][m] = sfun(raw_data[algo][m][sim.TIMESTEPS])
            end
        end
    end
    processed_data
end

function run_simulations(ltr::Range, sim::Simulation)
    println("Simulating:")

    # Run parallel simulations
    raw::Array{Dict{String,Any},1} = @sync @parallel (vcat) for lt in ltr
        println(lt)
        sim.LIAR_THRESHOLD = lt
        simulate(sim)
    end

    # Set up final results dictionary
    gridrows = length(ltr)
    results = Dict{String,Any}()
    @inbounds for algo in sim.ALGOS
        results[algo] = Dict{String,Dict}()
        for s in sim.STATISTICS
            results[algo][s] = Dict{String,Array}()
            for m in [sim.METRICS, "components"]
                results[algo][s][m] = zeros(gridrows)
            end
        end
    end

    # Sort results using liar_threshold values
    @inbounds for (row, liar_threshold) in enumerate(ltr)
        i = 1
        matched = Dict{String,Dict}()
        for i = 1:gridrows
            if raw[i]["liar_threshold"] == liar_threshold
                matched = splice!(raw, i)
                break
            end
        end
        results["iterate"] = matched["iterate"]
        for algo in sim.ALGOS
            for s in sim.STATISTICS
                for m in [sim.METRICS, "components"]
                    results[algo][s][m][row,1] = matched[algo][s][m]
                end
            end
        end
    end
    save_data(sim, results, ltr)
end

function run_simulations(ltr::Range;
                         algos::Vector{ASCIIString}=["fixed-variance"],
                         save_raw_data::Bool=false)
    sim = Simulation()
    sim.ALGOS = algos
    sim.SAVE_RAW_DATA = save_raw_data
    run_simulations(ltr, sim)
end
