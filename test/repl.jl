using Simulator
using DataFrames
using Dates
using Debug
using JointMoments
using Distributions
using PyCall

@pyimport pyconsensus

# test/tinker.jl

liar_thresholds = 0.35:0.3:0.95
param_range = 5:5:250

sim = Simulation()

include("defaults_liar.jl")

sim.VERBOSE = true

# Quick run-thru
sim.EVENTS = 10
sim.REPORTERS = 20
sim.ITERMAX = 5
sim.TIMESTEPS = 25

# Full(er) run
# sim.EVENTS = 50
# sim.REPORTERS = 100
# sim.ITERMAX = 250
# sim.TIMESTEPS = 500

sim.SCALARS = 0.0
sim.REP_RAND = false
sim.REP_RANGE = 1:int(sim.TIMESTEPS/2)
# sim.REP_RANGE = 1:sim.TIMESTEPS
# sim.REP_RANGE = 1:(sim.TIMESTEPS*2)

# "Preferential attachment" market size distribution
sim.MARKET_DIST = Pareto(3.0)

sim.BRIDGE = false
sim.CORRUPTION = 0.75
sim.RARE = 1e-5
sim.MONEYBIN = first(find(pdf(sim.MARKET_DIST, 1:1e4) .< sim.RARE))

sim.SAVE_RAW_DATA = false
sim.ALGOS = [
   "cokurtosis",
   "sztorc",
   "fixed-variance",
   "virial",
   "covariance",
]

# src/simulate.jl

# run_simulations()

parallel = false
ltr = liar_thresholds

sim.LIAR_THRESHOLD = ltr[1]

print_with_color(:red, "Simulating:\n")
print_with_color(:yellow, "Liar threshold: " * repr(sim.LIAR_THRESHOLD) * "\n")

sim = preprocess(sim)
~sim.VERBOSE || xdump(sim)

# simulate()

iterate = (Int64)[]
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
    # raw_data[algo]["repcount"] = Dict{Int,Vector{Dict{Float64,Int}}}()
    # for t in timesteps
    #     raw_data[algo]["repcount"][t] = Dict{Float64,Int}[]
    # end
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

metrics = Dict{Symbol,Float64}()
data = Dict{Symbol,Any}()
i = t = 1
algo = "cokurtosis"
reputation = zeros(sim.REPORTERS)

# Simulate over #TIMESTEPS consensus resolutions:
#   - The previous (smoothed) reputation is used as an input to
#     the next time step
#   - Reporters' labels (true, liar, etc.) do not change
#   - Correct answers and reports are generated fresh at each
#     time step
reporters = create_reporters(sim)
metrics = Dict{Symbol,Float64}()
for t = 1:sim.TIMESTEPS

    # Create reporters and assign each reporter a label
    # Generate reports and correct answers
    data = generate_data(sim, reporters)

    # Assign/update reputation
    reputation = (t == 1) ?
        init_reputation(sim) : A[algo]["agents"]["smooth_rep"]
    repbox[algo][:,t,i] = reputation
    repdelta[algo][:,t,i] = reputation - repbox[algo][:,1,i]

    if sim.VERBOSE
        print_with_color(:white, "t = $t:\n")
        display([data[:reporters] repdelta[algo][:,:,i]])
        println("")

        # print_with_color(:white, "Reputation [" * algo * "]:\n")
        # display(reputation')
        # println("")

        # print_with_color(:white, "Reports [" * algo * "]:\n")
        # display(data[:reports])
        # println("")
    end

    # Per-user cokurtosis contribution
    data[:aux] = [
        :cokurt => JointMoments.collapse(
            data[:reports],
            reputation;
            order=4,
            standardize=false,
            axis=2,
            normalized=true,
            bias=0,
        )
    ]
    # if sim.VERBOSE
    #     print_with_color(:white, "Collapsed [" * algo * "]:\n")
    #     display(data[:aux])
    #     println("")
    # end

    # Use pyconsensus for event resolution
    A[algo] = pyconsensus.Oracle(
        reports=data[:reports],
        reputation=reputation,
        alpha=sim.ALPHA,
        variance_threshold=sim.VARIANCE_THRESHOLD,
        aux=data[:aux],
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

    if sim.VERBOSE
        # print_with_color(:white, "Oracle output [" * algo * "]:\n")
        # display(A[algo])
        # println("")
        # display(A[algo]["agents"])
        # println("")
        # display(A[algo]["events"])
        # println("")

        print_with_color(:white, "Metrics [" * algo * "]:\n")
        display(metrics)
        println("")
    end

    # Track the system's evolution
    for tr in sim.TRACK
        track[algo][tr][t,i] = metrics[tr]
    end
end
