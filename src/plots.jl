using Simulator
using DataFrames
using Gadfly

# Build plotting dataframe
function build_dataframe(sim_data::Dict{String,Any})
    const num_algos = length(sim_data["sim"].ALGOS)
    const num_metrics = length(sim_data["sim"].METRICS)
    const gridrows = length(sim_data["liar_threshold"])
    const liar_threshold = repmat(sim_data["liar_threshold"],
                                  num_algos*num_metrics,
                                  1)[:] * 100
    data = (Float64)[]
    algos = (String)[]
    metrics = (String)[]
    error_minus = (Float64)[]
    error_plus = (Float64)[]
    for algo in sim_data["sim"].ALGOS
        for m in sim_data["sim"].METRICS
            m_std = m * "_std"
            data = [data, sim_data[algo][m][:,1]]
            metrics = [metrics, fill!(Array(String, gridrows), m)]
            error_minus = [
                error_minus,
                sim_data[algo][m][:,1] - sim_data[algo][m_std][:,1],
            ]
            error_plus = [
                error_plus,
                sim_data[algo][m][:,1] + sim_data[algo][m_std][:,1],
            ]
        end
        algos = [
            algos,
            repmat(fill!(Array(String, gridrows),
                         string(uppercase(algo[1]), algo[2:end])),
                   num_metrics, 1)[:],
        ]
    end
    DataFrame(
        metric=metrics[:],
        liar_threshold=liar_threshold[:],
        data=data[:],
        error_minus=error_minus[:],
        error_plus=error_plus[:],
        algorithm=algos[:],
    )
end

# Plotting dataframe for each metric separately
function build_dataframe(sim_data::Dict{String,Any}, metric::String)
    const num_algos = (metric == "components") ? 1 : length(sim_data["sim"].ALGOS)
    const gridrows = length(sim_data["liar_threshold"])
    const liar_threshold = repmat(sim_data["liar_threshold"], num_algos, 1)[:] * 100
    data = (Float64)[]
    algos = (String)[]
    error_minus = (Float64)[]
    error_plus = (Float64)[]
    for algo in sim_data["sim"].ALGOS
        if metric == "components" && algo != "fixed-variance"
            continue
        end
        data = [data, sim_data[algo][metric][:,1]]
        error_minus = [
            error_minus,
            sim_data[algo][metric][:,1] - sim_data[algo][metric * "_std"][:,1],
        ]
        error_plus = [
            error_plus,
            sim_data[algo][metric][:,1] + sim_data[algo][metric * "_std"][:,1],
        ]
        algos = [
            algos,
            repmat(fill!(Array(String, gridrows),
                         string(uppercase(algo[1]), algo[2:end])),
                   1, 1)[:],
        ]
    end
    DataFrame(
        liar_threshold=liar_threshold[:],
        data=data[:],
        error_minus=error_minus[:],
        error_plus=error_plus[:],
        algorithm=algos[:],
    )
end

# Plot all metrics vs liar_threshold value
function plot_dataframe(df::DataFrame, title::String)
    pl = plot(df,
        x=:liar_threshold,
        y=:data,
        ymin=:error_minus,
        ymax=:error_plus,
        ygroup=:metric,
        color=:algorithm,
        Guide.XLabel("% liars"),
        Guide.YLabel(""),
        Guide.Title(title),
        Theme(panel_stroke=color("#848484")),
        Scale.y_continuous(format=:plain),
        Geom.subplot_grid(
            Geom.point,
            Geom.line,
            Geom.errorbar,
            free_y_axis=true,
        ),
    )
    pl_file = "plots/metrics_" * repr(now()) * ".svg"
    draw(SVG(pl_file, 12inch, 12inch), pl)
    print_with_color(:white, "Stacked plot: ")
    print_with_color(:cyan, "$pl_file\n")
end

function plot_dataframe(df::DataFrame, title::String, metric::String)
    pl = plot(df,
        x=:liar_threshold,
        y=:data,
        ymin=:error_minus,
        ymax=:error_plus,
        color=:algorithm,
        Guide.XLabel("% liars"),
        Guide.YLabel(metric),
        Guide.Title(title),
        Theme(panel_stroke=color("#848484")),
        Scale.y_continuous(
            format=:plain,
            minvalue=minimum(df[:error_minus]),
            maxvalue=maximum(df[:error_plus]),
        ),
        Geom.point,
        Geom.line,
        Geom.errorbar,
    )
    pl_file = "plots/single/" * metric * "_" * repr(now()) * ".svg"
    draw(SVG(pl_file, 10inch, 7inch), pl)
end

capitalize(algo::String) = string(uppercase(algo[1]), algo[2:end])

# String containing info about simulation (goes in figure title)
function build_title(sim::Simulation)
    optstr = ""
    for flag in (:CONSPIRACY, :ALLWRONG, :INDISCRIMINATE, :STEADYSTATE)
        optstr *= (sim.(flag)) ? " " * string(flag) : ""
    end
    string(
        sim.REPORTERS,
        " users reporting on ",
        sim.EVENTS,
        " events over ",
        sim.TIMESTEPS,
        " timesteps (",
        sim.ITERMAX,
        " iterations @ γ = ",
        sim.COLLUDE,
        ")",
        optstr,
    )
end

build_title(sim::Simulation, algo::String) = string(capitalize(algo),
                                                    ": ",
                                                    build_title(sim))

# Time series plots
function plot_trajectories(sim::Simulation,
                           trajectories::Vector{Trajectory},
                           liar_thresholds::Vector{Float64},
                           algo::String,
                           title::String)
    data = Float64[]
    metrics = String[]
    error_minus = Float64[]
    error_plus = Float64[]
    timesteps = Int[]
    liars = String[]
    for (i, lt) in enumerate(liar_thresholds)
        for tr in sim.TRACK
            data = [data, trajectories[i][algo][tr][:mean]]
            metrics = [metrics, fill!(Array(String, sim.TIMESTEPS), string(tr))]
            error_minus = [
                error_minus,
                trajectories[i][algo][tr][:mean] - trajectories[i][algo][tr][:stderr],
            ]
            error_plus = [
                error_plus,
                trajectories[i][algo][tr][:mean] + trajectories[i][algo][tr][:stderr],
            ]
            timesteps = [timesteps, [1:sim.TIMESTEPS]]
            liars = [
                liars,
                fill!(Array(String, sim.TIMESTEPS), string(lt))[:],
            ]
        end
    end
    df = DataFrame(
        metric=metrics[:],
        timesteps=timesteps[:],
        data=data[:],
        error_minus=error_minus[:],
        error_plus=error_plus[:],
        liars=liars[:],
    )
    pl = plot(df,
        x=:timesteps,
        y=:data,
        ymin=:error_minus,
        ymax=:error_plus,
        ygroup=:metric,
        color=:liars,
        # Guide.xticks(ticks=timesteps),
        Guide.XLabel("time (reporting round)"),
        Guide.YLabel(""),
        Guide.Title(title),
        Theme(panel_stroke=color("#848484")),
        Scale.y_continuous(format=:plain),
        Geom.subplot_grid(
            Geom.line,
            Geom.ribbon,
            free_y_axis=true,
        ),
    )
    pl_file = string("plots/trajectory_", algo, "_", repr(now()), ".svg")
    draw(SVG(pl_file, 12inch, 12inch), pl)
    print_with_color(:yellow, algo)
    print_with_color(:white, " time series: ")
    print_with_color(:cyan, "$pl_file\n")
end

function plot_trajectories(sim::Simulation,
                           trajectories::Vector{Trajectory},
                           liar_thresholds::Vector{Float64},
                           algo::String,
                           title::String,
                           tr::Symbol)
    data = Float64[]
    error_minus = Float64[]
    error_plus = Float64[]
    timesteps = Int[]
    liars = String[]
    for (i, lt) in enumerate(liar_thresholds)
        data = [data, trajectories[i][algo][tr][:mean]]
        error_minus = [
            error_minus,
            trajectories[i][algo][tr][:mean] - trajectories[i][algo][tr][:stderr],
        ]
        error_plus = [
            error_plus,
            trajectories[i][algo][tr][:mean] + trajectories[i][algo][tr][:stderr],
        ]
        timesteps = [timesteps, [1:sim.TIMESTEPS]]
        liars = [
            liars,
            fill!(Array(String, sim.TIMESTEPS), string(lt))[:],
        ]
    end
    df = DataFrame(
        timesteps=timesteps[:],
        data=data[:],
        error_minus=error_minus[:],
        error_plus=error_plus[:],
        liars=liars[:],
    )
    pl = plot(df,
        x=:timesteps,
        y=:data,
        ymin=:error_minus,
        ymax=:error_plus,
        color=:liars,
        Guide.XLabel("time (reporting round)"),
        Guide.YLabel(string(tr)),
        Guide.Title(title),
        Theme(panel_stroke=color("#848484")),
        Scale.y_continuous(
            format=:plain,
            minvalue=minimum(df[:error_minus]),
            maxvalue=maximum(df[:error_plus]),
        ),
        Geom.line,
        Geom.ribbon,
    )
    pl_file = string("plots/single/trajectory_",
                     algo, "_", tr, "_", repr(now()), ".svg")
    draw(SVG(pl_file, 10inch, 7inch), pl)
    println("  -> ", pl_file)
end

# Gadfly plots
function plot_simulations(sim_data::Dict{String,Any})
    print_with_color(:red, "Building plots...\n")

    trajectories = pop!(sim_data, "trajectories")
    title = build_title(sim_data["sim"])
    
    # Stacked plots with all metrics
    plot_dataframe(build_dataframe(sim_data), title)

    # Separate plots for each metric
    if "fixed-variance" in sim_data["sim"].ALGOS
        metrics = [sim_data["sim"].METRICS, "components"]
    else
        metrics = sim_data["sim"].METRICS
    end
    for m in metrics
        plot_dataframe(build_dataframe(sim_data, m), title, m)
    end
    print_with_color(:white, "Individual plots saved to ")
    print_with_color(:cyan, "plots/single/\n")

    # Time series plots
    sim = pop!(sim_data, "sim")
    for algo in sim.ALGOS
        trajectory_title = build_title(sim, algo)

        # Stacked plots
        plot_trajectories(sim,
                          trajectories,
                          sim_data["liar_threshold"],
                          algo,
                          trajectory_title)

        # Separate tracking metrics
        for tr in sim.TRACK
            plot_trajectories(sim,
                              trajectories,
                              sim_data["liar_threshold"],
                              algo,
                              trajectory_title,
                              tr)
        end
    end
end
