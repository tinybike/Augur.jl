@everywhere using Simulator

liar_thresholds = 0.1:0.1:0.9
param_range = 5:5:1000

sim = Simulation()

simtype = "cplx"
if length(ARGS) > 0
    if ARGS[1] == "cplx"
        simtype = "cplx"
    elseif ARGS[1] == "liar"
        simtype = "liar"
    else
        exit("Unknown mode")
    end
end

include("defaults_" * simtype * ".jl")

# Quick run-thru
# sim.EVENTS = 10
# sim.REPORTERS = 25
# sim.ITERMAX = 10
# sim.TIMESTEPS = 5

# Full(er) run
sim.EVENTS = 50
sim.REPORTERS = 100
sim.ITERMAX = 250
sim.TIMESTEPS = 250

sim.REP_RAND = true
sim.SAVE_RAW_DATA = false
sim.ALGOS = [
   "sztorc",
   "fixed-variance",
   "covariance",
   "cokurtosis",
   "cokurtosis-old",
]

# Run simulations and save results:
#   - binary classifier quality metrics
#   - graphical algorithm comparison
if simtype == "liar"
    @time sim_data = run_simulations(liar_thresholds, sim)
    plot_simulations(sim_data)

# Timing/complexity
elseif simtype == "cplx"
    println("Timed simulations:")
    # @time complexity(param_range, sim; iterations=1000, param="reporters")
    # @time complexity(param_range, sim; iterations=1000, param="events")
    @time complexity(param_range, sim; iterations=100, param="both")
end
