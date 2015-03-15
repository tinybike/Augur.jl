@everywhere using Simulator

liar_thresholds = 0.1:0.1:0.9
param_range = 10:5:40

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

sim.SAVE_RAW_DATA = false
sim.ALGOS = [
#    "sztorc",
#    "fixed-variance",
#    "cokurtosis",
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
    # @time complexity(param_range, sim; iterations=250, param="reporters")
    # @time complexity(param_range, sim; iterations=250, param="events")
    @time complexity(param_range, sim; iterations=25, param="both")
end
