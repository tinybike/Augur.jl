tic()

@everywhere using Augur
using Distributions

liar_thresholds = 0.75:0.1:0.95
param_range = 5:5:250

sim = Simulation()

srcpath = joinpath(Pkg.dir("Augur"), "src")
testpath = joinpath(Pkg.dir("Augur"), "test")

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

joinpath(Pkg.dir("Augur"), "test", "defaults_noise.jl")
include(joinpath(testpath, "defaults_" * simtype * ".jl"))

sim.VERBOSE = false
sim.COLLUDE = 0.33

sim.EVENTS = 25
sim.REPORTERS = 50
sim.ITERMAX = 50
sim.TIMESTEPS = 100

sim.INDISCRIMINATE = false
sim.CONSPIRACY = true
sim.NUM_CONSPIRACIES = 4
sim.SCALARS = 0.0
sim.SCALARMIN = 0.0
sim.SCALARMAX = 1000.0
sim.REP_RAND = false
sim.REP_DIST = Pareto(2.0)

sim.HIERARCHICAL_THRESHOLD = 0.5
sim.HIERARCHICAL_LINKAGE = :average
sim.CLUSTERFECK_THRESHOLD = 0.5
sim.DBSCAN_EPSILON = 0.25
sim.DBSCAN_MINPOINTS = 1
sim.AFFINITY_DAMPENING = 0.8

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
    "affinity",
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
        include(joinpath(srcpath, "pyplots.jl"))
        for metric in sim.METRICS
            plot_overlay(sim,
                         sim_data["trajectories"],
                         [liar_thresholds],
                         symbol(metric))
        end
    elseif plots == "gadfly"
        include(joinpath(srcpath, "plots.jl"))
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
