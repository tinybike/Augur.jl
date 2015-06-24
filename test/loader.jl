using Simulator
using DataFrames
using Dates

# EXAMPLE = "data/sim_2015-06-24T02:45:10.jld" # conspiracy
# EXAMPLE = "data/sim_2015-06-24T05:50:19.jld" # randomness
EXAMPLE = "data/sim_2015-06-24T05:50:19.jld" # parameter sampling

function load_and_plot_data(datafile::String; simtype::String="liar")
    println("Loading $datafile...")
    plot_simulations(load_data(datafile))
end

if length(ARGS) > 0 && ARGS[1] == "cplx"
    datafile = "data/time_both_2015-03-15T05:31:06.jld"
    (time_elapsed, sim, parameter, iterations, param_range, timestamp) = load_time_elapsed(datafile)
    timestamp = repr(now())
    df = DataFrame(
        param=[param_range],
        time_elapsed=time_elapsed[:mean],
        error_minus=time_elapsed[:mean]-time_elapsed[:std],
        error_plus=time_elapsed[:mean]+time_elapsed[:std],
    )
    plot_time_elapsed(df, timestamp, parameter, infostring(sim, iterations))
else
    datafile = (isinteractive() || length(ARGS) == 0) ? EXAMPLE : ARGS[1]
    load_and_plot_data(datafile)
    # sim_data = load_data(datafile)
    # sim = pop!(sim_data, "sim")
    # trajectories = pop!(sim_data, "trajectories")
    # liar_thresholds = pop!(sim_data, "liar_threshold")
end
