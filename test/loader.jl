# Load and plot Julia data sets
# Syntax: julia loader.jl <plotter> <datafile>
# Options for <plotter> are gadfly and pyplot.
# Example: julia loader.jl gadfly data/sim_2015-07-01T23:02:41.jld

using Augur
using DataFrames
using Dates

DATAFILE = "data/sim_2015-07-01T23:02:41.jld" # example

srcpath = joinpath(Pkg.dir("Augur"), "src")

plots = nothing
if ~isinteractive() && length(ARGS) > 0
    if ARGS[1] == "pyplot"
        plots = "pyplot"
    elseif ARGS[1] == "gadfly"
        plots = "gadfly"
    end
end
if isinteractive() && plots == nothing
    plots = "pyplot"
end
if length(ARGS) > 1
    DATAFILE = ARGS[2]
end

if length(ARGS) > 0 && ARGS[1] == "cplx"
    if length(ARGS) > 1
        DATAFILE = ARGS[2]
    else
        DATAFILE = "data/time_both_2015-03-15T05:31:06.jld"
    end
    (time_elapsed, sim, parameter, iterations, param_range, timestamp) = load_time_elapsed(DATAFILE)
    timestamp = repr(now())
    df = DataFrame(
        param=[param_range],
        time_elapsed=time_elapsed[:mean],
        error_minus=time_elapsed[:mean]-time_elapsed[:std],
        error_plus=time_elapsed[:mean]+time_elapsed[:std],
    )
    plot_time_elapsed(df, timestamp, parameter, infostring(sim, iterations))
else
    if plots != nothing
        println("Loading data: ", DATAFILE)
        if plots == "gadfly"
            include(joinpath(srcpath, "plots.jl"))
            plot_simulations(load_data(DATAFILE))
        elseif plots == "pyplot"
            include(joinpath(srcpath, "pyplots.jl"))
            sim_data = load_data(DATAFILE)
            sim = pop!(sim_data, "sim")
            trajectories = pop!(sim_data, "trajectories")
            liar_thresholds = pop!(sim_data, "liar_threshold")
            for metric in sim.METRICS
                plot_overlay(sim, trajectories, liar_thresholds, symbol(metric))
            end
        end
    end
end
