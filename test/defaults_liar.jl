sim.EVENTS = 50
sim.REPORTERS = 100
sim.ITERMAX = 250
sim.TIMESTEPS = 1
# sim.STEADYSTATE = false
sim.LIAR_THRESHOLD = 0.6
sim.VARIANCE_THRESHOLD = 0.9
# sim.DISTORT = 0.0
# sim.RESPONSES = -1:1
# sim.ALPHA = 0.2
# sim.REP_BINS = int(sim.REPORTERS/10)
sim.REP_RANGE = 1:100
sim.REP_RAND = false
sim.COLLUDE = 0.3
sim.INDISCRIMINATE = true
# sim.VERBOSE = false
# sim.CONSPIRACY = false
# sim.ALLWRONG = false
sim.SAVE_RAW_DATA = false
sim.ALGOS = [
    "sztorc",
    "fixed-variance",
    # "covariance",
    "cokurtosis",
]
sim.METRICS = [
    "beats",
    "liars_bonus",
    "correct",
    "sensitivity",
    "fallout",
    "precision",
    "MCC",
    "gini",
    "true_rep",
    "liar_rep",
    "gap",
]
sim.TRACK = [
    :gini,
    :MCC,
    :correct,
    :gap,
]
sim.STATISTICS = ["mean", "stderr"]
