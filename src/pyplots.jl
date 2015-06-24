using Simulator
using Dates
using PyPlot

# PyPlot.matplotlib[:rc]("backend", "Qt4Agg")
PyPlot.matplotlib[:rc]("backend", qt4="PySide")
PyPlot.matplotlib[:rc]("lines", linewidth="1.15")
PyPlot.matplotlib[:rc]("lines", linestyle="-")
PyPlot.matplotlib[:rc]("lines", color="black")
PyPlot.matplotlib[:rc]("lines", markeredgewidth="0")
PyPlot.matplotlib[:rc]("lines", markersize="5.5")
PyPlot.matplotlib[:rc]("lines", solid_joinstyle="round")
PyPlot.matplotlib[:rc]("lines", solid_capstyle="round")
PyPlot.matplotlib[:rc]("lines", antialiased="True")
PyPlot.matplotlib[:rc]("font", family="serif")
PyPlot.matplotlib[:rc]("font", style="normal")
PyPlot.matplotlib[:rc]("font", variant="normal")
PyPlot.matplotlib[:rc]("font", weight="medium")
PyPlot.matplotlib[:rc]("font", stretch="normal")
PyPlot.matplotlib[:rc]("font", size="12.0")
PyPlot.matplotlib[:rc]("font", serif="Open Sans")
# PyPlot.matplotlib[:rc]("font", serif="Times, Palatino, New Century Schoolbook, Bookman, Computer Modern Roman")
# PyPlot.matplotlib[:rc]("font", sans_serif="Arial, Helvetica, Avant Garde, Computer Modern Sans serif")
PyPlot.matplotlib[:rc]("axes", hold=false)
PyPlot.matplotlib[:rc]("axes", facecolor="white")
PyPlot.matplotlib[:rc]("axes", edgecolor="black")
PyPlot.matplotlib[:rc]("axes", linewidth="1.0")
PyPlot.matplotlib[:rc]("axes", grid=true)
PyPlot.matplotlib[:rc]("axes", titlesize="22.0")
PyPlot.matplotlib[:rc]("axes", labelsize="14.0")
PyPlot.matplotlib[:rc]("axes", labelweight="normal")
PyPlot.matplotlib[:rc]("axes", labelcolor="black")
PyPlot.matplotlib[:rc]("axes", axisbelow=true)
PyPlot.matplotlib[:rc]("axes", color_cycle=["8A084B",
                                            "8A084B",
                                            "8A084B",
                                            # "5DA5DA",  # blue
                                            # "60BD68",  # green
                                            # "B276B2",  # purple
                                            "0174DF",
                                            "0174DF",
                                            "0174DF",
                                            # "F15854",  # red
                                            # "FAA43A",  # orange
                                            # "B2912F",  # brown
                                            "F17CB0",  # pink
                                            "DECF3F",  # yellow
                                            "4D4D4D"]) # gray
PyPlot.matplotlib[:rc]("axes", xmargin="0")
PyPlot.matplotlib[:rc]("axes", ymargin="0")
PyPlot.matplotlib[:rc]("grid", color="0.7")
PyPlot.matplotlib[:rc]("grid", linestyle="solid")
PyPlot.matplotlib[:rc]("grid", linewidth="0.5")
PyPlot.matplotlib[:rc]("grid", alpha="0.2")
PyPlot.matplotlib[:rc]("savefig", dpi="300")
PyPlot.matplotlib[:rc]("savefig", format="png")
PyPlot.matplotlib[:rc]("savefig", bbox="tight")
PyPlot.matplotlib[:rc]("savefig", pad_inches="0.1")
PyPlot.matplotlib[:rc]("savefig", jpeg_quality="95")
PyPlot.matplotlib[:rc]("figure", figsize="9,6")
PyPlot.matplotlib[:rc]("figure", dpi="150")
PyPlot.matplotlib[:rc]("figure", facecolor="white")
# PyPlot.matplotlib[:rc]("figure", edgecolor="white")
PyPlot.matplotlib[:rc]("figure", autolayout=true)

axis_labels = (Symbol => String)[
    :MCC => "Matthews correlation coefficient",
    :correct => "% answers determined correctly",
    :beats => "beats",
    :liars_bonus => "liars' bonus",
    :spearman => "Spearman's rho",
    :liar_rep => "% Reputation held by liars",
    :true_rep => "% Reputation held by honest reporters",
]

function plot_overlay(sim::Simulation,
                      trajectories::Vector{Trajectory},
                      liar_thresholds::Vector{Float64},
                      metric::Symbol)
    time_max = sim.TIMESTEPS
    timesteps = [1:time_max]
    fig = PyPlot.figure()
    lgnd = ["", "", "", "", "", ""]
    mrkr = ["+", ".", "d", "+", ".", "d"]
    for (j, algo) in enumerate(("clusterfeck", "PCA"))
        label = (algo == "clusterfeck") ? "Augur" : "Truthcoin"
        k = 1
        for (i, lt) in enumerate(liar_thresholds)
            if lt == 0.55 || lt == 0.65 || lt == 0.85
                PyPlot.errorbar(timesteps,
                                trajectories[i][algo][metric][:mean][1:time_max]*100,
                                marker=mrkr[k],
                                yerr=trajectories[i][algo][metric][:stderr][1:time_max]*100)
                # lgnd[k + (j-1)*3] = label * " (" * string(int(lt*100)) * "% liars)"
                lgnd[k + (j-1)*3] = label * " (" * string(int(lt*100)) * "% noise)"
                hold("on");
                k += 1
            end
        end
    end
    PyPlot.xlabel("time (number of consecutive reporting rounds elapsed)")
    PyPlot.ylabel(axis_labels[metric])
    # PyPlot.title("Conspiracy")
    PyPlot.title("Randomness")
    PyPlot.grid()
    PyPlot.legend(lgnd, loc="center right", bbox_to_anchor=(1.375, 0.55), ncol=1)
    pl_file = "plots/overlay_" * string(metric) * "_" * repr(Dates.now()) * ".png"
    fig[:canvas][:draw]()
    PyPlot.savefig(pl_file)
    print_with_color(:white, "  overlay: ")
    print_with_color(:cyan, "$pl_file\n")
end

if isdefined(:sim) && isdefined(:trajectories) && isdefined(:liar_thresholds)
    plot_overlay(sim, trajectories, liar_thresholds, :liar_rep)
    plot_overlay(sim, trajectories, liar_thresholds, :correct)
end
