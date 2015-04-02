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

sim.LIAR_THRESHOLD = 0.85

sim.EVENTS = 25
sim.REPORTERS = 50
sim.ITERMAX = 1
sim.TIMESTEPS = 100

sim.SCALARS = 0.0
sim.REP_RAND = true
sim.REP_DIST = Pareto(3.0)

sim.MARKET_DIST = Pareto(3.0)
sim.BRIDGE = false
sim.CORRUPTION = 0.75
sim.RARE = 1e-5
sim.MONEYBIN = first(find(pdf(sim.MARKET_DIST, 1:1e4) .< sim.RARE))

sim.ALGOS = [
   "cokurtosis",
   "sztorc",
   "fixed-variance",
   "virial",
]

# src/simulate.jl
# run_simulations()
sim = preprocess(sim)

# simulate()

i = 1
reporters = []
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

reputation = zeros(sim.REPORTERS)
reporters = create_reporters(sim)
metrics = Dict{Symbol,Float64}()
data = Dict{Symbol,Any}()

i = t = 1
for algo in sim.ALGOS
    for t = 1:sim.TIMESTEPS
        data = generate_data(sim, reporters)
        reputation = (t == 1) ? init_reputation(sim) : A[algo]["agents"]["smooth_rep"]
        repbox[algo][:,t,i] = reputation
        repdelta[algo][:,t,i] = reputation - repbox[algo][:,1,i]
        
        if algo == "cokurtosis"
            data[:aux] = [
                :cokurt => collapse(data[:reports], reputation; order=4, axis=2, normalized=true)
            ]
        elseif algo == "covariance"
            data[:aux] = [
                :cov => collapse(data[:reports], reputation; axis=2, normalized=true)
            ]
        elseif algo == "virial"
            data[:aux] = [:H => zeros(sim.REPORTERS)]
            for o = 2:2:sim.VIRIALMAX
                data[:aux][:H] += collapse(data[:reports], reputation; order=o, axis=2, normalized=true) / o
            end
            data[:aux][:H] = normalize(data[:aux][:H])
        end

        A[algo] = pyconsensus.Oracle(
            reports=data[:reports],
            reputation=reputation,
            alpha=sim.ALPHA,
            variance_threshold=sim.VARIANCE_THRESHOLD,
            aux=data[:aux],
            algorithm=algo,
        )[:consensus]()

        metrics = compute_metrics(
            sim,
            data,
            A[algo]["events"]["outcomes_final"],
            reputation,
            A[algo]["agents"]["smooth_rep"],
        )
        for tr in sim.TRACK
            track[algo][tr][t,i] = metrics[tr]
        end
    end
end
