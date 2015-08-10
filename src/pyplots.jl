using Augur
using Dates
using PyPlot

include("../src/pyplot-settings.jl")

# if > 10 curves per algo are needed, additional markers can be found here:
# http://matplotlib.org/api/markers_api.html
MARKERS = ["s", "o", "d", "v", "^", ">", "<", "*", "p", "D"]
COLOR_SEQUENCE = [
    "8A084B",
    "0174DF",
    "60BD68",
    "F15854",
    "5DA5DA",
    "B276B2",
    "FAA43A",
    "B2912F",
    "F17CB0",
    "DECF3F",
    "4D4D4D",
]

function build_title(sim::Simulation)
    optstr = ""
    flags = (:REP_RAND,
             :DISTORTER,
             :ALLWRONG,
             :INDISCRIMINATE,
             :BRIDGE,
             :SCALARS)
    for flag in flags
        optstr *= (sim.(flag) > 0) ? " " * string(flag) : ""
    end
    if sim.CONSPIRACY 
        if sim.NUM_CONSPIRACIES > 1
            optstr *= " CONSPIRACIES [" * string(sim.NUM_CONSPIRACIES) * "]"
        else
            optstr *= " CONSPIRACY"
        end
    end
    string(
        sim.REPORTERS,
        " users reporting on ",
        sim.EVENTS,
        " events over ",
        sim.TIMESTEPS,
        " timesteps (",
        sim.ITERMAX,
        " iterations @ gamma = ",
        sim.COLLUDE,
        ")",
        optstr,
    )
end

build_title(sim::Simulation, algo::String) = string(capitalize(algo),
                                                    ": ",
                                                    build_title(sim))

function plot_overlay(sim::Simulation,
                      trajectories::Vector{Trajectory},
                      liar_thresholds::Vector{Float64},
                      metric::Symbol)
    time_max = sim.TIMESTEPS
    timesteps = [1:time_max]
    fig = PyPlot.figure()
    num_curves = length(liar_thresholds)
    num_algos = length(sim.ALGOS)
    markers = MARKERS[1:num_curves]
    color_cycle = ASCIIString[]
    for j = 1:num_algos
        color = COLOR_SEQUENCE[j]
        for i = 1:num_curves
            push!(color_cycle, color)
        end
    end
    PyPlot.matplotlib[:rc]("axes", color_cycle=color_cycle)
    lgnd = fill("", num_curves*num_algos)
    y_min = 100.0
    y_max = -100.0
    for (j, algo) in enumerate(sim.ALGOS)
        k = 1
        for (i, lt) in enumerate(liar_thresholds)
            y_points = trajectories[i][algo][metric][:mean][1:time_max]*100
            y_errors = trajectories[i][algo][metric][:stderr][1:time_max]*100
            PyPlot.errorbar(timesteps, y_points, marker=markers[k], yerr=y_errors)
            y_min = min(y_min, minimum(y_points - abs(y_errors)))
            y_max = max(y_max, maximum(y_points + abs(y_errors)))
            lgnd[k + (j-1)*num_curves] = algo * " (" * string(int(lt*100)) * "% noise)"
            hold("on")
            k += 1
        end
    end
    PyPlot.xlabel("time (number of consecutive reporting rounds elapsed)")
    PyPlot.ylabel(sim.AXIS_LABELS[metric])
    PyPlot.ylim([y_min - 1, y_max + 1])
    PyPlot.title(build_title(sim))
    PyPlot.grid()
    PyPlot.legend(lgnd,
        loc="center right",
        bbox_to_anchor=(1.32, 0.55),
        ncol=1
    )
    pl_file = joinpath(
        Pkg.dir("Augur"),
        "test",
        "plots",
        "overlay_" * string(metric) * "_" * repr(Dates.now()) * ".png"
    )
    PyPlot.savefig(pl_file)
    print_with_color(:grey, "saved plot: ")
    print_with_color(:cyan, "$pl_file\n")
end
