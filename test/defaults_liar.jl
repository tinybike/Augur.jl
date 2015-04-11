sim.EVENTS = 50
sim.REPORTERS = 100
sim.ITERMAX = 250
sim.TIMESTEPS = 1
sim.SCALARS = 0.25
sim.SCALARMIN = 0.0
sim.SCALARMAX = 1000.0
sim.LIAR_THRESHOLD = 0.6
# sim.DISTORT_THRESHOLD = 0.1
sim.VARIANCE_THRESHOLD = 0.9
# sim.DISTORT = 0.0
# sim.DISTORTER = false
# sim.ALPHA = 0.2
sim.REP_RAND = false
sim.REP_DIST = Uniform()
sim.BRIDGE = true
sim.MARKET_DIST = Exponential()
sim.PRICE_DIST = Uniform()
sim.OVERLAP_DIST = Exponential()
sim.CORRUPTION = 0.5
sim.COLLUDE = 0.3
sim.INDISCRIMINATE = true
# sim.VERBOSE = false
# sim.CONSPIRACY = false
# sim.ALLWRONG = false
sim.LABELSORT = true
sim.SAVE_RAW_DATA = false
sim.ALGOS = [
    "big-five",
    "fixed-variance",
]
sim.METRICS = [
    "beats",
    "liars_bonus",
    "distorts_bonus",
    "correct",
    "MCC",
    "gini",
    "true_rep",
    "liar_rep",
    "distorts_rep",
    "gap",
    "corrupted",
]
sim.TRACK = [
    :gini,
    :MCC,
    :correct,
    :beats,
    :distorts_rep,
    :liars_bonus,
    :corrupted,
]
sim.STATISTICS = ["mean", "stderr"]
