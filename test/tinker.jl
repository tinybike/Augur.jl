@everywhere using Simulator

liar_thresholds = 0.1:0.1:0.9

sim = Simulation()

# include("defaults_liar.jl")
include("defaults_cplx.jl")

sim.SAVE_RAW_DATA = true
sim.ALGOS = [
    # "sztorc",
    # "fixed-variance",
    "cokurtosis",
]

# Run simulations and save results
# @time sim_data = run_simulations(liar_thresholds, sim)
# plot_simulations(sim_data)

@time complexity(10:10:100, sim; iterations=5, param="reporters")
# @time complexity(10:5:100, sim; iterations=5, param="events")
# @time complexity(10:5:100, sim; iterations=5, param="both")
