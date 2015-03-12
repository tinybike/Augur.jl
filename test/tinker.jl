@everywhere using Simulator

liar_thresholds = 0.1:0.1:0.9

sim = Simulation()
sim.EVENTS = 25
sim.REPORTERS = 25
sim.ITERMAX = 50
sim.TIMESTEPS = 10
# sim.STEADYSTATE = false
# sim.LIAR_THRESHOLD = 0.6
# sim.VARIANCE_THRESHOLD = 0.9
# sim.DISTORT = 0.0
# sim.RESPONSES = -1:1
# sim.ALPHA = 0.2
# sim.BETA = 0.75
sim.REP_RANGE = 1:100
sim.REP_RAND = false
sim.COLLUDE = 0.3
sim.INDISCRIMINATE = true
# sim.VERBOSE = false
# sim.CONSPIRACY = false
# sim.ALLWRONG = false
sim.SAVE_RAW_DATA = true
sim.ALGOS = [
    # "sztorc",
    # "fixed-variance",
    # "covariance",
    "cokurtosis",
    # "inverse-scores",
    # "coskewness",
]
sim.METRICS = [
    "beats",
    "liars_bonus",
    "correct",
    "sensitivity",
    "fallout",
    "precision",
    "MCC",
]
sim.STATISTICS = ["mean", "stderr"]

# Run simulations and save results
# @time sim_data = run_simulations(liar_thresholds, sim)
# plot_simulations(sim_data)

complexity(10:5:100, sim, param="REPORTERS")
complexity(10:5:100, sim, param="EVENTS")
complexity(10:5:100, sim, param="BOTH")
