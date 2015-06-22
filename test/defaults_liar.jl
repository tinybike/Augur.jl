sim.EVENTS = 125
sim.REPORTERS = 250
sim.ITERMAX = 500
sim.TIMESTEPS = 250
sim.SCALARS = 0.25
sim.SCALARMIN = 0.0
sim.SCALARMAX = 1000.0
sim.LIAR_THRESHOLD = 0.6
sim.VARIANCE_THRESHOLD = 0.9
sim.REP_RAND = false
sim.REP_DIST = Uniform()
sim.BRIDGE = true
sim.MARKET_DIST = Exponential()
sim.PRICE_DIST = Uniform()
sim.OVERLAP_DIST = Exponential()
sim.CORRUPTION = 0.5
sim.COLLUDE = 0.3
sim.INDISCRIMINATE = true
sim.LABELSORT = true
sim.SAVE_RAW_DATA = false
sim.ALGOS = [
    "PCA",
    "clusterfeck",
    "k-means",
    "hierarchical",
    "fixed-variance",
]
sim.METRICS = [
    "beats",
    "liars_bonus",
    "correct",
    "MCC",
    "true_rep",
    "liar_rep",
    "spearman",
]
sim.TRACK = [
    :MCC,
    :correct,
    :beats,
    :liars_bonus,
    :liar_rep,
    :spearman,
]
sim.STATISTICS = ["mean", "stderr"]
