@everywhere using Simulator

liar_thresholds = 0.025:0.025:0.95

sim = Simulation()
sim.EVENTS = 50
sim.REPORTERS = 100 
sim.ITERMAX = 500
sim.TIMESTEPS = 1000
# sim.STEADYSTATE = false
# sim.LIAR_THRESHOLD = 0.6
# sim.VARIANCE_THRESHOLD = 0.9
# sim.DISTORT = 0.0
# sim.RESPONSES = -1:1
# sim.ALPHA = 0.2
# sim.BETA = 0.75
# sim.REP_RANGE = 1:25
# sim.REP_RAND = false
sim.COLLUDE = 0.7
sim.INDISCRIMINATE = true
# sim.VERBOSE = false
# sim.CONSPIRACY = false
# sim.ALLWRONG = false
sim.SAVE_RAW_DATA = true
sim.ALGOS = [
    "sztorc",
    "fixed-variance",
    # "covariance",
    # "cokurtosis",
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
plot_simulations(run_simulations(liar_thresholds, sim))
