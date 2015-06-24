tic()

@everywhere using Simulator
using Distributions

liar_thresholds = 0.35:0.1:0.95
param_range = 5:5:250

sim = Simulation()

simtype = "liar"
if ~isinteractive() && length(ARGS) > 0
    if ARGS[1] == "cplx"
        simtype = "cplx"
    elseif ARGS[1] == "liar"
        simtype = "liar"
    else
        println("Unknown mode")
        exit()
    end
end

include("defaults_" * simtype * ".jl")

sim.VERBOSE = false
sim.COLLUDE = 0.5

# Quick run-thru
sim.EVENTS = 100
sim.REPORTERS = 250
sim.ITERMAX = 100
sim.TIMESTEPS = 125

# Full(er) run
# sim.EVENTS = 250
# sim.REPORTERS = 500
# sim.ITERMAX = 250
# sim.TIMESTEPS = 125

sim.INDISCRIMINATE = false
sim.CONSPIRACY = true
sim.NUM_CONSPIRACIES = 4
sim.SCALARS = 0.0
sim.REP_RAND = true
sim.REP_DIST = Pareto(3.0)

# "Preferential attachment" market size distribution
sim.MARKET_DIST = Pareto(3.0)

sim.ALPHA = 0.1
sim.BRIDGE = false
sim.CORRUPTION = 0.75
sim.RARE = 1e-5
sim.MONEYBIN = first(find(pdf(sim.MARKET_DIST, 1:1e4) .< sim.RARE))
sim.MAX_COMPONENTS = 5
sim.LABELSORT = false
sim.SAVE_RAW_DATA = false
sim.HISTOGRAM = false
sim.ALGOS = [
    "PCA",
    #"fixed-variance",
    #"big-five",
    # "k-means",
    "hierarchical",
    "clusterfeck",
]

# Run simulations and save results:
#   - binary classifier quality metrics
#   - graphical algorithm comparison
if simtype == "liar"
    @time sim_data = run_simulations(liar_thresholds, sim; parallel=true)
    # plot_reptrack(sim_data)
    plot_simulations(sim_data)

# Timing/complexity
elseif simtype == "cplx"
    println("Timed simulations:")
    @time complexity(param_range, sim; iterations=1000, param="reporters")
    @time complexity(param_range, sim; iterations=1000, param="events")
    @time complexity(param_range, sim; iterations=1000, param="both")
end

t = toq()
if t <= 60
    units = "seconds"
elseif 60 < t <= 3600
    t /= 60
    units = "minutes"
elseif 3600 < t <= 86400
    t /= 3600
    units = "hours"
else
    t /= 86400
    units = "days"
end
print_with_color(:white, string(round(t, 4), " ", units, " elapsed\n"))
