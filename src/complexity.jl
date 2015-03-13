function save_time_elapsed(time_elapsed::Dict{Symbol,Vector{Float64}},
                           timestamp::String)
    filename = "data/time_" * param * "_" * timestamp * ".jld"
    jldopen(filename, "w") do file
        write(file, "time_elapsed", time_elapsed)
    end
    println("Data saved to ", filename)
end

function plot_time_elapsed(time_elapsed::Dict{Symbol,Vector{Float64}},
                           timestamp::String,
                           param::String,
                           algorithm::String)
    df = DataFrame(
        param=[param_range],
        time_elapsed=time_elapsed[:mean],
        error_minus=time_elapsed[:mean]-time_elapsed[:std],
        error_plus=time_elapsed[:mean]+time_elapsed[:std],
    )
    println(display(df))
    pl = plot(df,
        x=:param,
        y=:time_elapsed,
        ymin=:error_minus,
        ymax=:error_plus,
        Guide.XLabel(param),
        Guide.YLabel("seconds elapsed"),
        Guide.Title(algorithm),
        Theme(panel_stroke=color("#848484")),
        Geom.point,
        Geom.line,
        Geom.errorbar,
    )
    pl_file = "plots/time_" * param * "_" * timestamp * ".svg"
    draw(SVG(pl_file, 10inch, 7inch), pl)
    println("Plot saved to ", pl_file)
end

function complexity(param_range::Range,
                    sim::Simulation;
                    iterations::Int=1,
                    param::String="events")
    println("Timed simulations: varying $param")

    # Warmup run
    @sync @parallel (vcat) for n = 1:nprocs()
        println("warming up")
        if param == "reporters"
            sim.REPORTERS = n
        elseif param == "events"
            sim.EVENTS = n
        elseif param == "both"
            sim.REPORTERS = n
            sim.EVENTS = n
        end
        @elapsed simulate(sim)
    end

    # Measure time elapsed
    raw::Array = @sync @parallel (vcat) for n in param_range
        println(n)
        sim.REPORTERS = 25
        sim.EVENTS = 25
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
        (mean(elapsed), std(elapsed) / sqrt(iterations))
    end

    # Timestamp when simulations complete
    timestamp = repr(now())

    # Juggle, save, and plot data
    L = length(param_range)
    time_elapsed = (Symbol => Vector{Float64})[
        :mean => zeros(L),
        :std => zeros(L),
    ]
    for i = 1:L
        time_elapsed[:mean][i] = raw[i][1]
        time_elapsed[:std][i] = raw[i][2]
    end
    save_time_elapsed(time_elapsed, timestamp)
    plot_time_elapsed(time_elapsed, timestamp, param, first(sim.ALGOS))
end
