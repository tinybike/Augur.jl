@everywhere using Simulator

liar_thresholds = 0.05:0.05:0.95
algos = [
    "sztorc",
    "cokurtosis",
    "FVT+cokurtosis",
    "fixed-variance",
]

# Run simulations
sim_data = run_simulations(liar_thresholds, algos=algos)

# Plot results and save to file
plot_simulations(sim_data)
