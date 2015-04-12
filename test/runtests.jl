@everywhere using Simulator
@everywhere using Base.Test
using Distributions

liar_thresholds = 0.8:0.2:0.8
param_range = 5:5:250

sim = Simulation()

include("defaults_liar.jl")

sim.VERBOSE = false

# sim.PRESET = true
# sim.PRESET_DATA = (Symbol => Any)[
#     :reporters => ,
#     :trues => ,
#     :distorts => ,
#     :liars => ,
#     :num_trues => ,
#     :num_distorts => ,
#     :num_liars => ,
#     :honesty => ,
#     :aux => nothing,
# ]

sim.EVENTS = 25
sim.REPORTERS = 50
sim.ITERMAX = 1
sim.TIMESTEPS = 1

sim.SCALARS = 0.0
sim.REP_RAND = false
sim.REP_DIST = Pareto(3.0)

sim.BRIDGE = false
sim.MAX_COMPONENTS = 5
sim.CONSPIRACY = false
sim.LABELSORT = false
sim.SAVE_RAW_DATA = false
sim.ALGOS = [
    "sztorc",
]

sim_data = run_simulations(liar_thresholds, sim; parallel=true)
# plot_reptrack(sim_data)
# plot_simulations(sim_data)

# include("defaults_cplx.jl")

# @time complexity(param_range, sim; iterations=100, param="reporters")
# @time complexity(param_range, sim; iterations=100, param="events")
# @time complexity(param_range, sim; iterations=100, param="both")
