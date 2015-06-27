@pyimport pyconsensus

# Convert raw data into means and standard errors for plotting
function process_raw_data(sim::Simulation,
                          raw_data::Dict{String,Any},
                          reptrack::Dict{String,Dict{String,Matrix{Float64}}},
                          iterate::Vector{Int64},
                          trajectory::Trajectory)
    processed_data = (String => Any)[
        "iterate" => iterate,
        "liar_threshold" => sim.LIAR_THRESHOLD,
        "trajectory" => trajectory,
    ]
    if sim.SURFACE
        processed_data["reptrack"] = reptrack
    end
    for algo in sim.ALGOS
        processed_data[algo] = Dict{String,Dict{String,Float64}}()
        for s in sim.STATISTICS
            processed_data[algo][s] = Dict{String,Float64}()
            for m in [sim.METRICS]
                if s == "mean"
                    processed_data[algo][s][m] = mean(raw_data[algo][m][sim.TIMESTEPS])
                elseif s == "stderr"
                    processed_data[algo][s][m] = std(raw_data[algo][m][sim.TIMESTEPS]) / sim.SQRTN
                end
            end
        end
    end
    return processed_data
end

# Sum down repbox tubes (for surface plots)
function reptrack_sums(sim::Simulation, repbox::Dict{String,Array{Float64,3}})
    reptrack = Dict{String,Dict{String,Matrix{Float64}}}()
    for algo in sim.ALGOS
        reptrack[algo] = Dict{String,Matrix{Float64}}()
        for s in ("mean", "median", "std")
            reptrack[algo][s] = squeeze(mean(repbox[algo], 3), 3)
        end
        if sim.VERBOSE
            print_with_color(:white, "Reputation evolution:\n")
            display(reptrack[algo]["mean"])
            println("")
        end
    end
    return reptrack
end

# Trajectories (time series data): mean +/- standard error
function calculate_trajectories(sim::Simulation,
                                track::Dict{String,Dict{Symbol,Matrix{Float64}}})
    trajectory = Trajectory()
    for algo in sim.ALGOS
        trajectory[algo] = Track()
        for tr in sim.TRACK
            trajectory[algo][tr] = (Symbol => Vector{Float64})[
                :mean => mean(track[algo][tr], 2)[:],
                :stderr => std(track[algo][tr], 2)[:] / sim.SQRTN,
            ]
        end
    end
    return trajectory
end

function save_raw_data(raw_data::Dict{String,Any},
                       track::Dict{String,Dict{Symbol,Matrix{Float64}}},
                       repbox::Dict{String,Array{Float64,3}},
                       repdelta::Dict{String,Array{Float64,3}})
    filename = "data/raw/raw_sim_" * repr(now()) * ".jld"
    jldopen(filename, "w") do file
        write(file, "raw_data", raw_data)
        write(file, "track", track)
        if sim.SURFACE
            write(file, "repbox", repbox)
            write(file, "repdelta", repdelta)
        end
    end
end

function track_evolution(sim::Simulation,
                         metrics::Dict{Symbol,Float64},
                         track::Dict{Symbol,Matrix{Float64}},
                         t::Int,
                         i::Int)
    for tr in sim.TRACK
        track[tr][t,i] = metrics[tr]
    end
    return track
end

function save_timestep_data(sim::Simulation,
                            raw_data::Dict{String,Any},
                            metrics::Dict{Symbol,Float64},
                            algo::String,
                            t::Int)
    for m in sim.METRICS
        push!(raw_data[algo][m][t], metrics[symbol(m)])
    end
    if sim.HISTOGRAM
        push!(raw_data[algo]["repcount"][t], metrics[:repcount])
    end
    return raw_data
end

function print_oracle_output(A, metrics, algo, t)
    print_with_color(:white, "Oracle output [" * algo * "]:\n")
    display(A[algo])
    println("")
    display(A[algo]["agents"])
    println("")
    display(A[algo]["events"])
    println("")

    print_with_color(:white, "Reputation [" * algo * "]:\n")
    display(reputation')
    println("")

    print_with_color(:white, "Reports [" * algo * "]:\n")
    display(data[t][:reports])
    println("")

    print_with_color(:white, "Metrics [" * algo * "]:\n")
    display(metrics)
    println("")
end

function print_repbox(repbox::Dict{String,Array{Float64,3}},
                      repdelta::Dict{String,Array{Float64,3}},
                      reputation, data, algo, t, i)
    repbox[algo][:,t,i] = reputation
    repdelta[algo][:,t,i] = reputation - repbox[algo][:,1,i]
    print_with_color(:white, "t = $t:\n")
    display([data[t][:reporters] repdelta[algo][:,:,i]])
    println("")

    print_with_color(:white, "Reputation [" * algo * "]:\n")
    display(reputation')
    println("")

    print_with_color(:white, "Reports [" * algo * "]:\n")
    display(data[t][:reports])
    println("")
end

function init_repbox(sim::Simulation)
    repbox = Dict{String,Array{Float64,3}}()
    repdelta = Dict{String,Array{Float64,3}}()
    for algo in sim.ALGOS
        repbox[algo] = zeros(sim.REPORTERS, sim.TIMESTEPS, sim.ITERMAX)
        repdelta[algo] = zeros(sim.REPORTERS, sim.TIMESTEPS, sim.ITERMAX)
    end
    return (repbox, repdelta)
end

function init_tracking(sim::Simulation)
    track = Dict{String,Dict{Symbol,Matrix{Float64}}}()
    A = Dict{String,Any}()
    for algo in sim.ALGOS
        A[algo] = Dict{String,Any}()
        track[algo] = Dict{Symbol,Matrix{Float64}}()
        for tr in sim.TRACK
            track[algo][tr] = zeros(sim.TIMESTEPS, sim.ITERMAX)
        end
    end
    return (A, track)
end

function init_raw_data(sim::Simulation)
    raw_data = (String => Any)[ "sim" => sim ]
    timesteps = (sim.SAVE_RAW_DATA) ? 1:sim.TIMESTEPS : sim.TIMESTEPS
    for algo in sim.ALGOS
        raw_data[algo] = Dict{String,Any}()
        for m in [sim.METRICS]
            raw_data[algo][m] = Dict{Int,Vector{Float64}}()
            for t in timesteps
                raw_data[algo][m][t] = Float64[]
            end
        end
        if sim.HISTOGRAM
            raw_data[algo]["repcount"] = Dict{Int,Vector{Dict{Float64,Int}}}()
            for t in timesteps
                raw_data[algo]["repcount"][t] = Dict{Float64,Int}[]
            end
        end
    end
    return raw_data
end

function simulate(sim::Simulation)
    iterate = (Int64)[]
    i = 1
    raw_data = init_raw_data(sim)::Dict{String,Any}
    (A, track) = init_tracking(sim)
    reptrack = Dict{String,Dict{String,Matrix{Float64}}}()

    # Reputation time series (repbox):
    # - column t is the reputation vector at time t
    # - third axis = iteration
    if sim.SURFACE
        (repbox, repdelta) = init_repbox(sim)
    end

    reporters = create_reporters(sim)::Dict{Symbol,Any}

    # print_with_color(:white, "Reporters:\n")
    # display(reporters)
    # println("")

    while i <= sim.ITERMAX

        # Initialize reporters and reputation
        init_rep = init_reputation(sim)

        # Create datasets (identical for each algorithm)
        data = convert(Vector{Any}, zeros(sim.TIMESTEPS));
        for t = 1:sim.TIMESTEPS
            data[t] = generate_data(sim, reporters)
        end
        # print_with_color(:white, "Data (iteration " * string(i) * ":\n")
        # display(data)
        # println("")

        for algo in sim.ALGOS

            # Simulate over #TIMESTEPS consensus resolutions:
            #   - The previous (smoothed) reputation is used as an input to
            #     the next time step
            #   - Reporters' labels (true, liar, etc.) do not change
            #   - Correct answers and reports are generated fresh at each
            #     time step
            metrics = Dict{Symbol,Float64}()
            for t = 1:sim.TIMESTEPS

                # Assign/update reputation
                reputation = (t == 1) ? init_rep : updated_rep

                if sim.VERBOSE
                    print_repbox(repbox, repdelta, reputation, data, algo, t, i)
                end

                # Use pyconsensus for event resolution
                A[algo] = pyconsensus.Oracle(
                    reports=data[t][:reports],
                    reputation=reputation,
                    alpha=sim.ALPHA,
                    variance_threshold=sim.VARIANCE_THRESHOLD,
                    max_components=sim.MAX_COMPONENTS,
                    algorithm=algo,
                )[:consensus]()

                updated_rep = convert(Vector{Float64}, A[algo]["agents"]["reporter_bonus"])

                # Measure this algorithm's performance
                metrics = compute_metrics(
                    sim,
                    data[t],
                    A[algo]["events"]["outcomes_final"],
                    reputation,
                    updated_rep,
                )::Dict{Symbol,Float64}

                if sim.VERBOSE || any(isnan(updated_rep))
                    print_oracle_output(A, metrics, algo, t)
                end

                if sim.SAVE_RAW_DATA || t == sim.TIMESTEPS
                    raw_data = save_timestep_data(sim, raw_data, metrics,
                                                  algo, t)::Dict{String,Any}
                end

                # Track the system's evolution
                track[algo] = track_evolution(sim, metrics, track[algo],
                                              t, i)::Dict{Symbol,Matrix{Float64}}
            end
        end

        push!(iterate, i)
        i += 1
    end

    if sim.SAVE_RAW_DATA
        save_raw_data(raw_data, track, repbox, repdelta)    
    end

    trajectory = calculate_trajectories(sim, track)::Trajectory

    if sim.SURFACE
        reptrack = reptrack_sums(sim, repbox)::Dict{String,Dict{String,Matrix{Float64}}}
    end

    process_raw_data(sim, raw_data, reptrack, iterate, trajectory)::Dict{String,Any}
end

function exclude(sim::Simulation, excluded::Tuple)
    for x in excluded
        sim.METRICS = sim.METRICS[sim.METRICS .!= string(x)]
        sim.TRACK = sim.TRACK[sim.TRACK .!= x]
    end
    return sim
end

function preprocess(sim::Simulation)
    sim = (sim.DISTORTER) ?
        exclude(sim, (:MCC, :sensitivity, :fallout, :precision)) :
        exclude(sim, (:distorts_bonus, :distorts_rep))
    (sim.BRIDGE) ?
        exclude(sim, (:beats, :liars_bonus, :sensitivity, :fallout,
                      :precision, :MCC, :true_rep, :liar_rep, :gap)) :
        exclude(sim, (:corrupted,))
end

function run_simulations(ltr::Range, sim::Simulation; parallel::Bool=false)
    print_with_color(:red, "Simulating:\n")
    sim = preprocess(sim)

    # Run parallel simulations
    if parallel && nprocs() > 1
        raw::Array{Dict{String,Any},1} = @sync @parallel (vcat) for lt in ltr
            println(lt)
            sim.LIAR_THRESHOLD = lt
            simulate(sim)
        end

    # Regular (serial) simulation
    else
        raw = Dict{String,Any}[]
        for (i, lt) in enumerate(ltr)
            print_with_color(:yellow, "Liar threshold: " * repr(lt) * "\n")
            sim.LIAR_THRESHOLD = lt
            raw = vcat(raw, simulate(sim))
        end
    end

    # Set up final results dictionary
    gridrows = length(ltr)
    results = Dict{String,Any}()
    for algo in sim.ALGOS
        results[algo] = Dict{String,Dict}()
        for s in sim.STATISTICS
            results[algo][s] = Dict{String,Array}()
            for m in [sim.METRICS]
                results[algo][s][m] = zeros(gridrows)
            end
        end
    end

    # Sort results using liar_threshold values
    if sim.VERBOSE
        results["reptracks"] = Array(Dict{String,Dict{String,Matrix{Float64}}}, gridrows)
    end
    results["trajectories"] = Array(Trajectory, gridrows)
    for (row, liar_threshold) in enumerate(ltr)
        i = 1
        matched = Dict{String,Dict}()
        for i = 1:gridrows
            if raw[i]["liar_threshold"] == liar_threshold
                matched = splice!(raw, i)
                break
            end
        end
        results["iterate"] = matched["iterate"]
        results["trajectories"][row] = matched["trajectory"]
        if sim.VERBOSE
            results["reptracks"][row] = matched["reptrack"]
        end
        for algo in sim.ALGOS
            for s in sim.STATISTICS
                for m in [sim.METRICS]
                    results[algo][s][m][row,1] = matched[algo][s][m]
                end
            end
        end
    end
    save_data(sim, results, ltr)
end

function run_simulations(ltr::Range;
                         algos::Vector{ASCIIString}=["cokurtosis"],
                         save_raw_data::Bool=false)
    sim = Simulation()
    sim.ALGOS = algos
    sim.SAVE_RAW_DATA = save_raw_data
    run_simulations(ltr, sim)
end
