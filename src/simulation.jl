@pyimport pyconsensus

# todo:
#   - label pairs, triples, quadruples
#   - mix conspiracy with regular collusion
#   - scalar event resolution (check reward/vote slopes)
#   - sensitivity analysis for FVT+cokurtosis parameter beta
#   - time-evolution of scalar statistics
#   - port "winning" algo to Serpent
#   - does Sztorc algo work better when PC1 accounts for more variance?
#   - plot number of components + % variance explained (scree plots)
#   - simulate repeatedly to get steady-state metrics

function compute_metrics(sim::Simulation,
                         data::Dict{Symbol,Any},
                         outcomes::Vector{Any},
                         this_rep::Vector{Float64})

    # "this_rep" is the reputation awarded this round (before smoothing)
    liars_bonus = this_rep - this_rep[first(find(data[:reporters] .== "true"))]
    [
        # "liars_bonus": bonus reward liars received (in excess of true reporters')
        :liars_bonus => sum(liars_bonus),

        # "beats" are liars that escaped punishment
        :beats => sum(liars_bonus[data[:liars]] .> 0) / data[:num_liars] * 100,

        # Outcomes that matched our known correct answers list
        :correct => countnz(outcomes .== data[:correct_answers]) / sim.EVENTS * 100,
    ]
end

function create_reporters(sim::Simulation)
    
    # simplest version: no distortion
    distort_threshold = sim.LIAR_THRESHOLD

    # 1. Generate artificial "true, distort, liar" list
    honesty = rand(sim.REPORTERS)
    reporters = fill("", sim.REPORTERS)
    reporters[honesty .>= distort_threshold] = "true"
    reporters[sim.LIAR_THRESHOLD .< honesty .< distort_threshold] = "distort"
    reporters[honesty .<= sim.LIAR_THRESHOLD] = "liar"

    # 2. Build report matrix from this list
    trues = find(reporters .== "true")
    distorts = find(reporters .== "distort")
    liars = find(reporters .== "liar")
    num_trues = length(trues)
    num_distorts = length(distorts)
    num_liars = length(liars)

    while num_trues == 0 || num_liars == 0
        honesty = rand(sim.REPORTERS)
        reporters = fill("", sim.REPORTERS)
        reporters[honesty .>= distort_threshold] = "true"
        reporters[sim.LIAR_THRESHOLD .< honesty .< distort_threshold] = "distort"
        reporters[honesty .<= sim.LIAR_THRESHOLD] = "liar"
        trues = find(reporters .== "true")
        distorts = find(reporters .== "distort")
        liars = find(reporters .== "liar")
        num_trues = length(trues)
        num_distorts = length(distorts)
        num_liars = length(liars)
    end

    (Symbol => Any)[
        :reporters => reporters,
        :trues => trues,
        :distorts => distorts,
        :liars => liars,
        :num_trues => num_trues,
        :num_distorts => num_distorts,
        :num_liars => num_liars,
        :honesty => honesty,
        :aux => nothing,
    ]
end

function generate_data(sim::Simulation, data::Dict{Symbol,Any})
    data[:correct_answers] = rand(sim.RESPONSES, sim.EVENTS)

    # True: always report correct answer
    data[:reports] = zeros(sim.REPORTERS, sim.EVENTS)
    data[:reports][trues,:] = convert
        Matrix{Float64},
        repmat(data[:correct_answers]', num_trues)
    )

    # Distort: sometimes report incorrect answers at random
    distmask = rand(num_distorts, sim.EVENTS) .< sim.DISTORT
    correct = convert(
        Matrix{Float64},
        repmat(data[:correct_answers]', num_distorts)
    )
    randomized = convert(
        Matrix{Float64},
        rand(sim.RESPONSES, num_distorts, sim.EVENTS)
    )
    data[:reports][distorts,:] = correct.*~distmask + randomized.*distmask

    # Liar: report answers at random (but with a high chance
    #       of being equal to other liars' answers)
    data[:reports][liars,:] = convert(
        Matrix{Float64},
        rand(sim.RESPONSES, num_liars, sim.EVENTS)
    )

    # "allwrong": liars always answer incorrectly
    if sim.ALLWRONG
        @inbounds for i = 1:num_liars
            for j = 1:sim.EVENTS
                while data[:reports][liars[i],j] == data[:correct_answers][j]
                    data[:reports][liars[i],j] = rand(sim.RESPONSES)
                end
            end
        end
    end

    # All-or-nothing collusion ("conspiracy")
    if sim.CONSPIRACY
        @inbounds for i = 1:num_liars-1
            diceroll = first(rand(1))
            if diceroll < sim.COLLUDE
                data[:reports][liars[i],:] = data[:reports][liars[1],:]
            end
        end
    end

    # Indiscriminate copying: liars copy anyone, not just other liars
    if sim.INDISCRIMINATE
        @inbounds for i = 1:num_liars

            # Pairs
            diceroll = first(rand(1))
            if diceroll < sim.COLLUDE
                target = int(ceil(first(rand(1))) * sim.REPORTERS)
                data[:reports][target,:] = data[:reports][liars[i],:]

                # Triples
                if diceroll < sim.COLLUDE^2
                    target2 = int(ceil(first(rand(1))) * sim.REPORTERS)
                    data[:reports][target2,:] = data[:reports][liars[i],:]

                    # Quadruples
                    if diceroll < sim.COLLUDE^3
                        target3 = int(ceil(first(rand(1))) * sim.REPORTERS)
                        data[:reports][target3,:] = data[:reports][liars[i],:]
                    end
                end
            end
        end

    # "Ordinary" (ladder) collusion
    # todo: remove num_liars upper bounds (these decrease collusion probs)
    else
        @inbounds for i = 1:num_liars-1

            # Pairs
            diceroll = first(rand(1))
            if diceroll < sim.COLLUDE
                data[:reports][liars[i+1],:] = data[:reports][liars[i],:]

                # Triples
                if i + 2 < num_liars
                    if diceroll < sim.COLLUDE^2
                        data[:reports][liars[i+2],:] = data[:reports][liars[i],:]
        
                        # Quadruples
                        if i + 3 < num_liars
                            if diceroll < sim.COLLUDE^3
                                data[:reports][liars[i+3],:] = data[:reports][liars[i],:]
                            end
                        end
                    end
                end
            end
        end
    end
    ~sim.VERBOSE || display([data[:reporters] data[:reports]])
    data
end

function simulate(sim::Simulation)
    iterate = (Int64)[]
    i = 1
    reporters = []
    B = Dict()
    @inbounds for algo in sim.ALGOS
        B[algo] = Dict()
        for m in sim.METRICS
            B[algo][m] = (Float64)[]
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
            for t = 1:sim.TIMESTEPS
                data = generate_data(sim, reporters)
                
                # Assign/update reputation
                if t == 1
                    reputation = (sim.REP_RAND) ? rand(sim.REP_RANGE, sim.REPORTERS) : ones(sim.REPORTERS)
                else
                    reputation = A[algo]["agents"]["smooth_rep"]
                end
                
                if algo == "coskewness"

                    # Coskewness tensor (cube)
                    tensor = coskew(data[:reports]'; standardize=true, bias=1)

                    # Per-user coskewness contribution
                    contrib = sum(sum(tensor, 3), 2)[:]
                    data[:aux] = [ :coskew => contrib / sum(contrib) ]

                elseif algo == "cokurtosis"

                    # Cokurtosis tensor (tesseract)
                    tensor = cokurt(data[:reports]'; standardize=true, bias=1)

                    # Per-user cokurtosis contribution
                    contrib = sum(sum(sum(tensor, 4), 3), 2)[:]
                    data[:aux] = [ :cokurt => contrib / sum(contrib) ]

                elseif algo == "FVT+cokurtosis"

                    # Cokurtosis tensor (tesseract)
                    tensor = cokurt(data[:reports]'; standardize=true, bias=1)

                    # Per-user cokurtosis contribution
                    contrib = sum(sum(sum(tensor, 4), 3), 2)[:]
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
            end
            metrics = compute_metrics(
                sim,
                data,
                A[algo]["events"]["outcomes_final"],
                A[algo]["agents"]["this_rep"],
            )
            push!(B[algo]["liars_bonus"], metrics[:liars_bonus])
            push!(B[algo]["beats"], metrics[:beats])
            push!(B[algo]["correct"], metrics[:correct])
            push!(B[algo]["components"], A[algo]["components"])
        end

        push!(iterate, i)
        i += 1
    end

    C = (String => Any)[
        "iterate" => iterate,
        "liar_threshold" => sim.LIAR_THRESHOLD,
    ]
    @inbounds for algo in sim.ALGOS
        C[algo] = (String => Dict{String,Float64})[
            "mean" => (String => Float64)[
                "liars_bonus" => mean(B[algo]["liars_bonus"]),
                "beats" => mean(B[algo]["beats"]),
                "correct" => mean(B[algo]["correct"]),
                "components" => mean(B[algo]["components"]),
            ],
            "stderr" => (String => Float64)[
                "liars_bonus" => std(B[algo]["liars_bonus"]) / sim.SQRTN,
                "beats" => std(B[algo]["beats"]) / sim.SQRTN,
                "correct" => std(B[algo]["correct"]) / sim.SQRTN,
                "components" => std(B[algo]["components"]) / sim.SQRTN,
            ],
        ]
    end
    return C
end

function run_simulations(ltr::Range;
                         algos::Vector{String}=["sztorc", "fixed-variance"])
    println("Simulating:")

    # Run parallel simulations
    sim = Simulation()
    sim.ALGOS = algos
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
            for m in sim.METRICS
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
        @simd for algo in sim.ALGOS
            @simd for s in sim.STATISTICS
                @simd for m in sim.METRICS
                    results[algo][s][m][row,1] = matched[algo][s][m]
                end
            end
        end
    end
    save_data(sim, results, ltr)
end

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

# Load data from .jld file
function load_data(datafile::String)
    jldopen(datafile, "r") do file
        read(file, "sim_data")
    end
end
