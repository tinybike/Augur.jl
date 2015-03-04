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
    const num_algos = length(sim_data["sim"].ALGOS)
    const gridrows = length(sim_data["liar_threshold"])
    const liar_threshold = repmat(sim_data["liar_threshold"],
                                  1, 1)[:] * 100
    data = (Float64)[]
    algos = (String)[]
    metrics = (String)[]
    error_minus = (Float64)[]
    error_plus = (Float64)[]
    for algo in sim_data["sim"].ALGOS
        data = [data, sim_data[algo][metric][:,1]]
        metrics = [metrics, fill!(Array(String, gridrows), metric)]
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
    pl_file = "plots/single/$metric_" * repr(now()) * ".svg"
    draw(SVG(pl_file, 10inch, 7inch), pl)
end

# String containing info about simulation (goes in figure title)
function build_title(sim_data::Dict{String,Any})
    optstr = ""
    for flag in (:CONSPIRACY, :ALLWRONG, :INDISCRIMINATE, :STEADYSTATE)
        optstr *= (sim_data["sim"].(flag)) ? " " * string(flag) : ""
    end
    string(
        sim_data["sim"].REPORTERS,
        " users reporting on ",
        sim_data["sim"].EVENTS,
        " events over ",
        sim_data["sim"].TIMESTEPS,
        " timesteps (",
        sim_data["sim"].ITERMAX,
        " iterations @ γ = ",
        sim_data["sim"].COLLUDE,
        ")",
        optstr,
    )
end

# Gadfly plots
function plot_simulations(sim_data::Dict{String,Any})
    println("Building plots...")
    title = build_title(sim_data)
    
    # Stacked plots with all metrics
    plot_dataframe(build_dataframe(sim_data), title)

    # Separate plots for each metric
    for m in sim_data["sim"].METRICS
        plot_dataframe(build_dataframe(sim_data, m), title, m)
    end
end
