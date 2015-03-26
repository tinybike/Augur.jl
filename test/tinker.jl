tic()

@everywhere using Simulator

liar_thresholds = 0.3:0.1:0.6
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

# Quick run-thru
# sim.EVENTS = 40
# sim.REPORTERS = 80
# sim.ITERMAX = 5
# sim.TIMESTEPS = 2

# Full(er) run
sim.EVENTS = 50
sim.REPORTERS = 100
sim.ITERMAX = 250
sim.TIMESTEPS = 500

sim.DISTORTER = false
# sim.DISTORT = 0.2
# sim.DISTORT_THRESHOLD = 0.35
sim.REP_RAND = true
sim.REP_RANGE = 1:1000 # rep_range > timesteps
sim.SAVE_RAW_DATA = false
sim.ALGOS = [
   "sztorc",
   "fixed-variance",
   "cokurtosis",
   "cokurtosis-old",
]

# Run simulations and save results:
#   - binary classifier quality metrics
#   - graphical algorithm comparison
if simtype == "liar"
    @time sim_data = run_simulations(liar_thresholds, sim; parallel=true)
    plot_simulations(sim_data)

# Timing/complexity
elseif simtype == "cplx"
    println("Timed simulations:")
    @time complexity(param_range, sim; iterations=500, param="reporters")
    @time complexity(param_range, sim; iterations=500, param="events")
    @time complexity(param_range, sim; iterations=500, param="both")
end

print_with_color(:white, string(round(toq()/60, 2), " minutes elapsed\n"))
