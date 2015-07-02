tic()

@everywhere using Simulator
using Distributions

liar_thresholds = 0.6:0.15:0.9
param_range = 5:5:250

sim = Simulation()

simtype = "noise"
plots = nothing
if ~isinteractive() && length(ARGS) > 0
    if ARGS[1] == "cplx"
        simtype = "cplx"
    elseif ARGS[1] == "noise"
        simtype = "noise"
    elseif ARGS[1] == "pyplot" || (length(ARGS) > 1 && ARGS[2] == "pyplot")
        plots = "pyplot"
    elseif ARGS[1] == "gadfly" || (length(ARGS) > 1 && ARGS[2] == "gadfly")
        plots = "gadfly"
    else
        println("Unknown mode")
        exit()
    end
end
if isinteractive() && simtype == "noise" && plots == nothing
    plots = "pyplot"    
end

include("defaults_" * simtype * ".jl")

sim.VERBOSE = false
sim.COLLUDE = 0.33

# Quick run-thru
sim.EVENTS = 25
sim.REPORTERS = 50
sim.ITERMAX = 25
sim.TIMESTEPS = 50

# Full(er) run
# sim.EVENTS = 100
# sim.REPORTERS = 250
# sim.ITERMAX = 100
# sim.TIMESTEPS = 125

sim.INDISCRIMINATE = false
sim.CONSPIRACY = false
sim.NUM_CONSPIRACIES = 4
sim.SCALARS = 0.0
sim.REP_RAND = false
sim.REP_DIST = Pareto(2.0)

sim.HIERARCHICAL_THRESHOLD = 0.5
sim.HIERARCHICAL_LINKAGE = :average
sim.CLUSTERFECK_THRESHOLD = 0.5
sim.DBSCAN_EPSILON = 0.5
sim.DBSCAN_MINPOINTS = 1

# "Preferential attachment" market size distribution
sim.MARKET_DIST = Pareto(2.0)

sim.ALPHA = 0.1
sim.BRIDGE = false
sim.CORRUPTION = 0.75
sim.RARE = 1e-5
sim.MONEYBIN = first(find(pdf(sim.MARKET_DIST, 1:1e4) .< sim.RARE))
sim.LABELSORT = false
sim.SAVE_RAW_DATA = false
sim.HISTOGRAM = false
sim.ALGOS = [
    "clusterfeck",
    "hierarchical",
    "PCA",
    "DBSCAN",
    # "affinity",
]

sim.METRICS = [
    "correct",
    "MCC",
    "liar_rep",
]
sim.TRACK = [
    "correct",
    "MCC",
    "liar_rep",
]

# Run simulations and save results:
#   - binary classifier quality metrics
#   - graphical algorithm comparison
if simtype == "noise"
    @time sim_data = run_simulations(liar_thresholds, sim; parallel=true)
    if plots == "pyplot"
        println("pyplot!")
        include("../src/pyplots.jl")
        for metric in sim.METRICS
            plot_overlay(sim,
                         sim_data["trajectories"],
                         [liar_thresholds],
                         symbol(metric))
        end
    elseif plots == "gadfly"
        include("../src/plots.jl")
        plot_simulations(sim_data)
    end

# Timing/complexity
elseif simtype == "cplx"
    println("Timed simulations:")
    @time complexity(param_range, sim; iterations=100, param="reporters")
    @time complexity(param_range, sim; iterations=100, param="events")
    @time complexity(param_range, sim; iterations=100, param="both")
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
