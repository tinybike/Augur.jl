function save_time_elapsed(time_elapsed::Dict{Symbol,Vector{Float64}},
                           timestamp::String,
                           param::String,
                           sim::Simulation,
                           iterations::Int,
                           param_range::Range)
    filename = "data/time_" * param * "_" * timestamp * ".jld"
    jldopen(filename, "w") do file
        write(file, "time_elapsed", time_elapsed)
        write(file, "sim", sim)
        write(file, "param", param)
        write(file, "iterations", iterations)
        write(file, "param_range", param_range)
        write(file, "timestamp", timestamp)
    end
    println("Data saved to ", filename)
end

function load_time_elapsed(datafile::String)
    jldopen(datafile, "r") do file
        time_elapsed = read(file, "time_elapsed")
        sim = read(file, "sim")
        param = read(file, "param")
        iterations = read(file, "iterations")
        param_range = read(file, "param_range")
        timestamp = read(file, "timestamp")
        (time_elapsed, sim, param, iterations, param_range, timestamp)
    end
end

function infostring(sim::Simulation, iterations::Int)
    string(
        first(sim.ALGOS),
        " timing (",
        repr(iterations),
        " simulations)",
    )
end

function plot_time_elapsed(df::DataFrame,
                           timestamp::String,
                           parameter::String,
                           title::String)
    xlabel = (parameter == "both") ? "events + reporters" : parameter
    if parameter == "both"
        df[:param] *= 2
    end
    pl = plot(df,
        x=:param,
        y=:time_elapsed,
        ymin=:error_minus,
        ymax=:error_plus,
        Guide.XLabel(xlabel),
        Guide.YLabel("seconds elapsed"),
        Guide.Title(title),
        Theme(panel_stroke=color("#848484")),
        Geom.point,
        Geom.line,
        Geom.errorbar,
    )
    pl_file = "plots/time_" * parameter * "_" * timestamp * ".svg"
    draw(SVG(pl_file, 10inch, 7inch), pl)
    println("Plot saved to ", pl_file)
end

function warmup(sim::Simulation, param::String)
    @sync @parallel (vcat) for n = 1:nprocs()
        println("warming up")
        @elapsed simulate(sim)
    end
end

function complexity(param_range::Range,
                    sim::Simulation;
                    iterations::Int=1,
                    param::String="events")    
    println("    Varying $param...")

    # Warmup run (needed for accurate timing)
    warmup(sim, param)

    # Measure time elapsed
    raw::Array = @sync @parallel (vcat) for n in param_range
        println(n)
        sim.REPORTERS = 10
        sim.EVENTS = 10
        if param == "reporters"
            sim.REPORTERS = n
        elseif param == "events"
            sim.EVENTS = n
        elseif param == "both"
            sim.REPORTERS = n
            sim.EVENTS = n
        end
        elapsed = zeros(iterations)
        for i = 1:iterations
            elapsed[i] = @elapsed simulate(sim)
        end
        println((mean(elapsed), std(elapsed)))
        (mean(elapsed), std(elapsed))
    end

    # Timestamp when simulations complete
    timestamp = repr(now())

    # Juggle and save data
    L = length(param_range)
    time_elapsed = (Symbol => Vector{Float64})[
        :mean => zeros(L),
        :std => zeros(L),
    ]
    for i = 1:L
        time_elapsed[:mean][i] = raw[i][1]
        time_elapsed[:std][i] = raw[i][2]
    end
    save_time_elapsed(time_elapsed,
                      timestamp,
                      param,
                      sim,
                      iterations,
                      param_range)

    # Plot data
    df = DataFrame(
        param=[param_range],
        time_elapsed=time_elapsed[:mean],
        error_minus=time_elapsed[:mean]-time_elapsed[:std],
        error_plus=time_elapsed[:mean]+time_elapsed[:std],
    )
    plot_time_elapsed(df, timestamp, param, infostring(sim, iterations))
end
