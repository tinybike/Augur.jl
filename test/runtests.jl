@everywhere using Simulator
using Base.Test

liar_thresholds = 0.1:0.8:0.9

# Run simulations, plot results and save to file
plot_simulations(run_simulations(liar_thresholds))
