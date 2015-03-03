@everywhere using Simulator

liar_thresholds = 0.05:0.05:0.95
algos = [
    "sztorc",
    "cokurtosis",
    "fixed-variance",
]

# Run simulations
sim_data = run_simulations(liar_thresholds, algos=algos, save_raw_data=true)

# Plot results and save to file
plot_simulations(sim_data)
