sim.EVENTS = 10
sim.REPORTERS = 10
sim.ITERMAX = 1
sim.TIMESTEPS = 1
sim.LIAR_THRESHOLD = 0.6
sim.VARIANCE_THRESHOLD = 0.9
sim.LABELSORT = false
sim.REP_DIST = Uniform()
sim.REP_RAND = false
sim.COLLUDE = 0.3
sim.INDISCRIMINATE = true
sim.SAVE_RAW_DATA = false
sim.HISTOGRAM = false
sim.ALGOS = ["clusterfeck"]
sim.METRICS = [
    "beats",
    "liars_bonus",
    "correct",
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
