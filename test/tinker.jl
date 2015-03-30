tic()

@everywhere using Simulator

# liar_thresholds = 0.35:0.1:0.95
liar_thresholds = 0.7:0.1:0.9
param_range = 5:5:250

sim = Simulation()

simtype = "liar"
if ~isinteractive() && length(ARGS) > 0
    if ARGS[1] == "cplx"
        simtype = "cplx"
    elseif ARGS[1] == "liar"
        simtype = "liar"
    else
        println("Unknown mode")
        exit()
    end
end

include("defaults_" * simtype * ".jl")

sim.VERBOSE = false

# Quick run-thru
# sim.EVENTS = 20
# sim.REPORTERS = 40
# sim.ITERMAX = 10
# sim.TIMESTEPS = 50

# Full(er) run
sim.EVENTS = 50
sim.REPORTERS = 100
sim.ITERMAX = 50
sim.TIMESTEPS = 150

sim.SCALARS = 0.0
sim.REP_RAND = true
# sim.REP_RANGE = 1:int(sim.TIMESTEPS/2)
sim.REP_RANGE = 1:sim.TIMESTEPS
# sim.REP_RANGE = 1:(sim.TIMESTEPS*2)
sim.SAVE_RAW_DATA = false
sim.ALGOS = [
   "sztorc",
   "fixed-variance",
   "cokurtosis",
   "cokurtosis-old",
]

# Run simulations and save results:
#   - binary classifier quality metrics
#   - graphical algorithm comparison
if simtype == "liar"
    @time sim_data = run_simulations(liar_thresholds, sim; parallel=true)
    plot_reptrack(sim_data)
    plot_simulations(sim_data)

# Timing/complexity
elseif simtype == "cplx"
    println("Timed simulations:")
    @time complexity(param_range, sim; iterations=500, param="reporters")
    @time complexity(param_range, sim; iterations=500, param="events")
    @time complexity(param_range, sim; iterations=500, param="both")
end

t = toq()
if t <= 60
    units = "seconds"
elseif 60 < t <= 3600
    t /= 60
    units = "minutes"
elseif 3600 < t <= 86400
    t /= 3600
    units = "hours"
else
    t /= 86400
    units = "days"
end
print_with_color(:white, string(round(t, 4), " ", units, " elapsed\n"))
