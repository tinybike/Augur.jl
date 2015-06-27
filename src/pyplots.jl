using Simulator
using Dates
using PyPlot

include("pyplot-settings.jl")

function plot_overlay(sim::Simulation,
                      trajectories::Vector{Trajectory},
                      liar_thresholds::Vector{Float64},
                      metric::Symbol)
    time_max = sim.TIMESTEPS
    timesteps = [1:time_max]
    fig = PyPlot.figure()
    lgnd = ["", "", "", "", "", ""]
    mrkr = ["s", "o", "d", "s", "o", "d"]
    for (j, algo) in enumerate(("hierarchical", "PCA"))
        label = (algo == "hierarchical") ? "Augur" : "Truthcoin"
        k = 1
        for (i, lt) in enumerate(liar_thresholds)
            if lt == 0.65 || lt == 0.75 || lt == 0.85
                PyPlot.errorbar(timesteps,
                                trajectories[i][algo][metric][:mean][1:time_max]*100,
                                marker=mrkr[k],
                                yerr=trajectories[i][algo][metric][:stderr][1:time_max]*100)
                lgnd[k + (j-1)*3] = label * " (" * string(int(lt*100)) * "% noise)"
                hold("on");
                k += 1
            end
        end
    end
    PyPlot.xlabel("time (number of consecutive reporting rounds elapsed)")
    PyPlot.ylabel(sim.AXIS_LABELS[metric])
    PyPlot.ylim([-1, 101])
    # PyPlot.title("Conspiracy")
    # PyPlot.title("Randomness")
    PyPlot.grid()
    PyPlot.legend(lgnd, loc="center right", bbox_to_anchor=(1.3, 0.55), ncol=1)
    pl_file = "plots/overlay_" * string(metric) * "_" * repr(Dates.now()) * ".png"
    fig[:canvas][:draw]()
    PyPlot.savefig(pl_file)
    print_with_color(:white, "  overlay: ")
    print_with_color(:cyan, "$pl_file\n")
end

if isdefined(:sim) && isdefined(:trajectories) && isdefined(:liar_thresholds)
    plot_overlay(sim, trajectories, liar_thresholds, :liar_rep)
    plot_overlay(sim, trajectories, liar_thresholds, :correct)
    plot_overlay(sim, trajectories, liar_thresholds, :sensitivity)
end
