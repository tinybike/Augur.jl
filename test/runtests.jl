using Simulator
using Base.Test
using DataFrames
using Dates
using JointMoments
using Distributions
using PyCall

@pyimport pyconsensus

sim = Simulation()
include("defaults_liar.jl")

sim.VERBOSE = false

sim.TESTING = true
sim.TEST_REPORTERS = ["true", "liar", "true", "liar", "liar", "liar"]
sim.TEST_INIT_REP = ones(length(sim.TEST_REPORTERS))
sim.TEST_CORRECT_ANSWERS = [ 2.0; 2.0; 1.0; 1.0 ]
sim.TEST_REPORTS = [ 2.0 2.0 1.0 1.0 ;
                     2.0 1.0 1.0 1.0 ;
                     2.0 2.0 1.0 1.0 ;
                     2.0 2.0 2.0 1.0 ;
                     1.0 1.0 2.0 2.0 ;
                     1.0 1.0 2.0 2.0 ]
sim.ITERMAX = 1
sim.TIMESTEPS = 1

sim.LIAR_THRESHOLD = 0.7
sim.VARIANCE_THRESHOLD = 0.9

sim.EVENTS = 4
sim.REPORTERS = 6

sim.SCALARS = 0.0
sim.REP_RAND = false
sim.REP_DIST = Pareto(3.0)

sim.BRIDGE = false
sim.MARKET_DIST = Pareto(3.0)
sim.CORRUPTION = 0.75
sim.RARE = 1e-5
sim.MONEYBIN = first(find(pdf(sim.MARKET_DIST, 1:1e4) .< sim.RARE))

sim.ALPHA = 0.1
sim.MAX_COMPONENTS = 5
sim.CONSPIRACY = false
sim.LABELSORT = false

sim.ALGOS = [ "sztorc", "big-five", "absolute" ]

# src/simulate.jl

sim = preprocess(sim)

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
track = Dict{String,Dict{Symbol,Matrix{Float64}}}()
A = Dict{String,Any}()
for algo in sim.ALGOS
    A[algo] = Dict{String,Any}()
    track[algo] = Dict{Symbol,Matrix{Float64}}()
    for tr in sim.TRACK
        track[algo][tr] = zeros(sim.TIMESTEPS, sim.ITERMAX)
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

sort_by_label = []
sort_by_rep = []
tokens = {}
metrics = {}
init_rep = []
reputation = []
timesteps = 1:sim.TIMESTEPS

if ~sim.TESTING
    reporters = create_reporters(sim)
else
    trues = find(sim.TEST_REPORTERS .== "true")
    distorts = find(sim.TEST_REPORTERS .== "distort")
    liars = find(sim.TEST_REPORTERS .== "liar")
    num_trues = length(trues)
    num_distorts = length(distorts)
    num_liars = length(liars)
    reporters = (Symbol => Any)[
        :reporters => sim.TEST_REPORTERS,
        :trues => trues,
        :distorts => distorts,
        :liars => liars,
        :num_trues => num_trues,
        :num_distorts => num_distorts,
        :num_liars => num_liars,
        :honesty => nothing,
        :aux => nothing,
    ]
end

i = t = 1
for i = 1:sim.ITERMAX

    # Initialize reporters and reputation
    if ~sim.TESTING
        init_rep = init_reputation(sim)
    else
        init_rep = sim.TEST_INIT_REP
    end
    metrics = Dict{Symbol,Float64}()

    # Create datasets (identical for each algorithm)
    data = convert(Vector{Any}, zeros(sim.TIMESTEPS));
    if ~sim.TESTING
        for t = 1:sim.TIMESTEPS
            data[t] = generate_data(sim, reporters)
        end
    else
        data[t] = (Symbol => Any)[
            :reporters => reporters[:reporters],
            :honesty => reporters[:honesty],
            :correct_answers => sim.TEST_CORRECT_ANSWERS,
            :distorts => reporters[:distorts],
            :reports => sim.TEST_REPORTS,
            :aux => nothing,
            :num_distorts => reporters[:num_distorts],
            :num_trues => reporters[:num_trues],
            :num_liars => reporters[:num_liars],
            :trues => reporters[:trues],
            :liars => reporters[:liars],
        ]
    end

    tokens = (Symbol => Float64)[
        :trues => sum(init_rep .* (reporters[:reporters] .== "true")),
        :liars => sum(init_rep .* (reporters[:reporters] .== "liar")),
        :distorts => sum(init_rep .* (reporters[:reporters] .== "distort")),
    ]

    sort_by_label = sortperm(reporters[:reporters])
    sort_by_rep = sortperm(init_rep)
    initdf = DataFrame(
        label_sort_by_label=reporters[:reporters][sort_by_label],
        reputation_sort_by_label=init_rep[sort_by_label],
        label_sort_by_rep=reporters[:reporters][sort_by_rep],
        reputation_sort_by_rep=init_rep[sort_by_rep],
    )
    reputation = copy(init_rep)

    for algo in sim.ALGOS
        for t = timesteps
            reportdf = convert(
                DataFrame,
                [["correct", reporters[:reporters]] [data[t][:correct_answers]', data[t][:reports]]],
            )

            reputation = (t == 1) ? init_rep : A[algo]["agents"]["smooth_rep"]
            repbox[algo][:,t,i] = reputation
            repdelta[algo][:,t,i] = reputation - repbox[algo][:,1,i]

            if algo == "cokurtosis"
                data[t][:aux] = [
                    :cokurt => collapse(data[t][:reports], reputation; order=4, axis=2, normalized=true)
                ]
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
            for tr in sim.TRACK
                track[algo][tr][t,i] = metrics[tr]
            end
        end
    end
end

@test round(A["sztorc"]["agents"]["reporter_bonus"], 6) == [ 0.178238 ;
                                                             0.171762 ;
                                                             0.178238 ;
                                                             0.171762 ;
                                                             0.15     ;
                                                             0.15     ]
@test round(track["sztorc"][:liars_bonus][1,1], 6) == -0.069425
@test round(A["big-five"]["agents"]["reporter_bonus"], 6) == [ 0.177957 ;
                                                               0.17433  ;
                                                               0.177957 ;
                                                               0.169755 ;
                                                               0.15     ;
                                                               0.15     ]
@test round(track["big-five"][:liars_bonus][1,1], 6) == -0.067744
