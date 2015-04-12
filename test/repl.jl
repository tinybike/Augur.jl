using Simulator
using DataFrames
using Dates
using JointMoments
using Distributions
using PyCall

@pyimport pyconsensus

# test/tinker.jl

sim = Simulation()
include("defaults_liar.jl")

sim.VERBOSE = false

sim.LIAR_THRESHOLD = 0.7
sim.VARIANCE_THRESHOLD = 0.9

sim.EVENTS = 40
sim.REPORTERS = 80
sim.ITERMAX = 25
sim.TIMESTEPS = 150

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
   "sztorc",
   "big-five",
   "absolute",
   "fixed-variance",
]

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

reporters = create_reporters(sim)

i = t = 1
for i = 1:sim.ITERMAX

    # Initialize reporters and reputation
    init_rep = init_reputation(sim)
    metrics = Dict{Symbol,Float64}()

    # Create datasets (identical for each algorithm)
    data = convert(Vector{Any}, zeros(sim.TIMESTEPS));
    for t = 1:sim.TIMESTEPS
        data[t] = generate_data(sim, reporters)
    end

    tokens = (Symbol => Float64)[
        :trues => sum(init_rep .* (reporters[:reporters] .== "true")),
        :liars => sum(init_rep .* (reporters[:reporters] .== "liar")),
        :distorts => sum(init_rep .* (reporters[:reporters] .== "distort")),
    ]

    # sort_by_label = sortperm(reporters[:reporters])
    # sort_by_rep = sortperm(init_rep)
    # initdf = DataFrame(
    #     label_sort_by_label=reporters[:reporters][sort_by_label],
    #     reputation_sort_by_label=init_rep[sort_by_label],
    #     label_sort_by_rep=reporters[:reporters][sort_by_rep],
    #     reputation_sort_by_rep=init_rep[sort_by_rep],
    # )
    reputation = copy(init_rep)

    for algo in sim.ALGOS
        for t = timesteps
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
            for tr in sim.TRACK
                track[algo][tr][t,i] = metrics[tr]
            end
        end
    end
end

# df = DataFrame(honesty=data[1][:reporters],
#                fixed_variance=repdelta["fixed-variance"][:,end,1],
#                big_five=repdelta["big-five"][:,end,1],
#                sztorc=repdelta["sztorc"][:,end,1],
#                absolute=repdelta["absolute"][:,end,1]);

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

mean_repdelta = Dict{String,Matrix{Float64}}()
std_repdelta = Dict{String,Matrix{Float64}}()
for algo in sim.ALGOS
    mean_repdelta[algo] = squeeze(sum(repdelta[algo], 3), 3)
    std_repdelta[algo] = squeeze(std(repdelta[algo], 3), 3)
end

mean_rep_liars = Dict{String,Vector{Float64}}()
std_rep_liars = Dict{String,Vector{Float64}}()
for algo in sim.ALGOS
    mean_rep_liars[algo] = vec(sum(mean_repdelta[algo][reporters[:liars],:],1))
    std_rep_liars[algo] = vec(std(std_repdelta[algo][reporters[:liars],:],1))
end
