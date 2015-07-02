using Simulator
using DataFrames
using Dates
using JointMoments
using Distributions
using PyCall

@pyimport pyconsensus

sim = Simulation()
include("defaults_noise.jl")

sim.VERBOSE = false

sim.LIAR_THRESHOLD = 0.7
sim.VARIANCE_THRESHOLD = 0.9

sim.EVENTS = 10
sim.REPORTERS = 20
sim.ITERMAX = 5
sim.TIMESTEPS = 15

sim.SCALARS = 0.0
sim.REP_RAND = true
sim.REP_DIST = Pareto(3.0)

sim.BRIDGE = false
sim.MARKET_DIST = Pareto(3.0)
sim.CORRUPTION = 0.75
sim.RARE = 1e-5
sim.MONEYBIN = first(find(pdf(sim.MARKET_DIST, 1:1e4) .< sim.RARE))

sim.MAX_COMPONENTS = 5
sim.CONSPIRACY = false

sim.VIRIALMAX = 8
sim.LABELSORT = true

sim.ALGOS = [
   "fixed-variance",
]

sim = preprocess(sim)

tokens = {}
metrics = {}
init_rep = []
reputation = []
timesteps = 1:sim.TIMESTEPS
reporters_range = 10:100
events_range = 10:100
components = zeros(length(reporters_range), length(events_range))
i = t = 1
for num_reporters = reporters_range
    idx1 = num_reporters - minimum(reporters_range) + 1
    sim.REPORTERS = num_reporters

    for num_events = events_range
        idx2 = num_events - minimum(events_range) + 1
        sim.EVENTS = num_events

        raw_data = (String => Any)[ "sim" => sim ]
        timesteps = (sim.SAVE_RAW_DATA) ? 1:sim.TIMESTEPS : sim.TIMESTEPS
        for algo in sim.ALGOS
            raw_data[algo] = Dict{String,Any}()
            for m in [sim.METRICS, "components"]
                raw_data[algo][m] = Dict{Int,Vector{Float64}}()
                for t in timesteps
                    raw_data[algo][m][t] = Float64[]
                end
            end
        end

        # Reputation time series (repbox):
        # - column t is the reputation vector at time t
        # - third axis = iteration
        repbox = Dict{String,Array{Float64,3}}()
        repdelta = Dict{String,Array{Float64,3}}()
        for algo in sim.ALGOS
            repbox[algo] = zeros(sim.REPORTERS, sim.TIMESTEPS, sim.ITERMAX)
            repdelta[algo] = zeros(sim.REPORTERS, sim.TIMESTEPS, sim.ITERMAX)
        end

        reporters = create_reporters(sim)
        raw_components = zeros(sim.ITERMAX)
        for i = 1:sim.ITERMAX

            # Initialize reporters and reputation
            init_rep = init_reputation(sim)
            metrics = Dict{Symbol,Float64}()

            # Create datasets (identical for each algorithm)
            data = convert(Vector{Any}, zeros(sim.TIMESTEPS));
            for t = 1:sim.TIMESTEPS
                data[t] = generate_data(sim, reporters)
            end
            t = 1

            tokens = (Symbol => Float64)[
                :trues => sum(init_rep .* (reporters[:reporters] .== "true")),
                :liars => sum(init_rep .* (reporters[:reporters] .== "liar")),
                :distorts => sum(init_rep .* (reporters[:reporters] .== "distort")),
            ]

            reputation = copy(init_rep)
            algo = "fixed-variance"

            for algo in sim.ALGOS
                for t = 1:sim.TIMESTEPS
                    # reportdf = convert(
                    #     DataFrame,
                    #     [["correct", reporters[:reporters]] [data[t][:correct_answers]', data[t][:reports]]],
                    # )

                    reputation = (t == 1) ? init_rep : A[algo]["agents"]["smooth_rep"]
                    repbox[algo][:,t,i] = reputation
                    repdelta[algo][:,t,i] = reputation - repbox[algo][:,1,i]
                    
                    if algo == "cokurtosis"
                        data[t][:aux] = [
                            :cokurt => collapse(data[t][:reports], reputation; order=4, axis=2, normalized=true)
                        ]
                    elseif algo == "virial"
                        data[t][:aux] = [:virial => zeros(sim.REPORTERS)]
                        for o = 2:2:sim.VIRIALMAX
                            data[t][:aux][:virial] += collapse(data[t][:reports], reputation; order=o, axis=2, normalized=true) / o
                        end
                        data[t][:aux][:virial] = normalize(data[t][:aux][:virial])
                    end

                    A[algo] = pyconsensus.Oracle(
                        reports=data[t][:reports],
                        reputation=reputation,
                        alpha=sim.ALPHA,
                        variance_threshold=sim.VARIANCE_THRESHOLD,
                        max_components=sim.MAX_COMPONENTS,
                        aux=data[t][:aux],
                        algorithm=algo,
                    )[:consensus]()

                    metrics = compute_metrics(
                        sim,
                        data[t],
                        A[algo]["events"]["outcomes_final"],
                        reputation,
                        A[algo]["agents"]["smooth_rep"],
                    )
                    if algo == "fixed-variance" && t == sim.TIMESTEPS
                        raw_components[i] = A[algo]["components"]
                    end
                end
            end
        end
        components[idx1,idx2] = mean(raw_components)
    end
end
