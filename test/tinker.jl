tic()

@everywhere using Simulator

liar_thresholds = 0.3:0.05:0.95
param_range = 10:10:1000

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
sim.EVENTS = 10
sim.REPORTERS = 25
sim.ITERMAX = 10
sim.TIMESTEPS = 5

# Full(er) run
# sim.EVENTS = 50
# sim.REPORTERS = 100
# sim.ITERMAX = 250
# sim.TIMESTEPS = 250

sim.REP_RAND = false
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
    @time complexity(param_range, sim; iterations=100, param="reporters")
    @time complexity(param_range, sim; iterations=100, param="events")
    @time complexity(param_range, sim; iterations=100, param="both")
end

print_with_color(:white, string("Minutes elapsed: ", round(toq()/60, 2)))
