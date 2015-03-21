using Simulator
using DataFrames
using Gadfly
using Debug

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
    println("Plot saved to ", pl_file)
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

# Time series plots
@debug function plot_trajectory(sim::Simulation,
                         trajectory::Dict{String,Dict{Symbol,Dict{Symbol,Vector{Float64}}}},
                         title::String)
    data = Float64[]
    metrics = String[]
    error_minus = Float64[]
    error_plus = Float64[]
    timesteps = Int[]
    algos = String[]
    for algo in sim.ALGOS
        for tr in sim.TRACK
            data = [data, trajectory[algo][tr][:mean]]
            metrics = [metrics, fill!(Array(String, sim.TIMESTEPS), string(tr))]
            error_minus = [
                error_minus,
                trajectory[algo][tr][:mean] - trajectory[algo][tr][:stderr],
            ]
            error_plus = [
                error_plus,
                trajectory[algo][tr][:mean] + trajectory[algo][tr][:stderr],
            ]
            timesteps = [timesteps, [1:sim.TIMESTEPS]]
        end
        algos = [
            algos,
            repmat(fill!(Array(String, sim.TIMESTEPS),
                         string(uppercase(algo[1]), algo[2:end])),
                   length(sim.TRACK), 1)[:],
        ]
    end
    @bp
    df = DataFrame(
        metric=metrics[:],
        timesteps=timesteps[:],
        data=data[:],
        error_minus=error_minus[:],
        error_plus=error_plus[:],
        algorithm=algos[:],
    )
    pl = plot(df,
        x=:timesteps,
        y=:data,
        ymin=:error_minus,
        ymax=:error_plus,
        ygroup=:metric,
        color=:algorithm,
        Guide.XLabel("report round"),
        Guide.YLabel(""),
        Guide.Title(title),
        Theme(panel_stroke=color("#848484")),
        Scale.y_continuous(format=:plain),
        Geom.subplot_grid(
            Geom.point,
            Geom.line,
            Geom.errorbar,
            free_y_axis=false,
        ),
    )
    pl_file = "plots/trajectory_" * repr(now()) * ".svg"
    draw(SVG(pl_file, 12inch, 12inch), pl)
    println("Time-series plot saved to ", pl_file)
end

# Gadfly plots
function plot_simulations(sim_data::Dict{String,Any})
    println("Building plots...")
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
    println("Individual plots saved to plots/single/")

    # Time series plots
    sim = pop!(sim_data, "sim")
    trajectory = pop!(sim_data, "trajectory")
    plot_trajectory(sim, trajectory, title)
end
