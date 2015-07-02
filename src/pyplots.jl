using Simulator
using Dates
using PyPlot

function plot_overlay(sim::Simulation,
                      trajectories::Vector{Trajectory},
                      liar_thresholds::Vector{Float64},
                      metric::Symbol)
    time_max = sim.TIMESTEPS
    timesteps = [1:time_max]
    fig = PyPlot.figure()
    # mrkr = ["s", "o", "d", "v"]
    mrkr = ["s", "o", "d"]
    num_curves = length(mrkr)
    lgnd = fill("", num_curves*length(sim.ALGOS))
    for (j, algo) in enumerate(sim.ALGOS)
        label = algo
        k = 1
        for (i, lt) in enumerate(liar_thresholds)
            PyPlot.errorbar(timesteps,
                            trajectories[i][algo][metric][:mean][1:time_max]*100,
                            marker=mrkr[k],
                            yerr=trajectories[i][algo][metric][:stderr][1:time_max]*100)
            lgnd[k + (j-1)*num_curves] = label * " (" * string(int(lt*100)) * "% noise)"
            hold("on")
            k += 1
        end
    end
    PyPlot.xlabel("time (number of consecutive reporting rounds elapsed)")
    PyPlot.ylabel(sim.AXIS_LABELS[metric])
    if metric == :MCC
        PyPlot.ylim([-101, 101])
    else
        PyPlot.ylim([-1, 101])
    end
    # PyPlot.title("Conspiracy")
    PyPlot.grid()
    PyPlot.legend(lgnd, loc="center right", bbox_to_anchor=(1.32, 0.55), ncol=1)
    pl_file = "plots/overlay_" * string(metric) * "_" * repr(Dates.now()) * ".png"
    fig[:canvas][:draw]()
    PyPlot.savefig(pl_file)
    print_with_color(:white, "  overlay: ")
    print_with_color(:cyan, "$pl_file\n")
end
