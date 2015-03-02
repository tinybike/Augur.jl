@everywhere using Simulator
using Base.Test

liar_thresholds = 0.05:0.05:0.95

# Run simulations, plot results and save to file
plot_simulations(run_simulations(liar_thresholds))
