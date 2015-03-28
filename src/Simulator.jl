module Simulator

    using Dates
    using PyCall
    using JointMoments
    using DataFrames
    using Gadfly
    using HDF5, JLD

    export
        Simulation,
        Trajectory,
        Track,
        generate_data,
        simulate,
        run_simulations,
        plot_simulations,
        build_title,
        plot_trajectories,
        load_data,
        save_data,
        complexity,
        load_time_elapsed,
        save_time_elapsed,
        plot_time_elapsed,
        infostring

    type Simulation

        # Report matrix size and number of iterations
        # (per parameter combination)
        EVENTS::Int
        REPORTERS::Int
        ITERMAX::Int
        SQRTN::Float64
        TIMESTEPS::Int

        # Fraction of scalar (non-boolean) events
        SCALARS::Float64
        SCALARMIN::Float64
        SCALARMAX::Float64

        # Fraction of dishonest/lazy reporters
        LIAR_THRESHOLD::Float64

        # Empirically, a 90% variance threshold seems best for the
        # fixed-variance threshold algorithm
        VARIANCE_THRESHOLD::Float64

        # True if there are "distort" type users that answer a fixed fraction
        # of events incorrectly
        DISTORTER::Bool

        # Fraction of incorrect responses from "distort" users
        DISTORT::Float64

        # Fraction of distorting users
        # i.e., LIAR_THRESHOLD=0.6    -> 60% liars
        #       DISTORT_THRESHOLD=0.2 -> 20% distorts
        DISTORT_THRESHOLD::Float64

        # Range of possible responses
        # -1:1 for {-1, 0, 1}, -1:2:1 for {-1, 1}, etc.
        RESPONSES::UnitRange{Int}

        # Reputation update smoothing parameter
        ALPHA::Float64

        # Allowed initial reputation values and whether randomized
        REP_BINS::Int
        REP_RANGE::UnitRange{Int}
        REP_RAND::Bool

        # Collusion: 0.2 => 20% chance liar will copy another user
        # (only other liars unless INDISCRIMINATE=true)
        COLLUDE::Float64
        INDISCRIMINATE::Bool
        VERBOSE::Bool
        CONSPIRACY::Bool
        ALLWRONG::Bool
        SAVE_RAW_DATA::Bool

        # Event resolution algorithms to test, metrics used to evaluate them,
        # and statistics of these metrics to calculate
        ALGOS::Vector{ASCIIString}
        METRICS::Vector{ASCIIString}
        STATISTICS::Vector{ASCIIString}

        # Tracking statistics for time series analysis
        TRACK::Vector{Symbol}

        Simulation(;events::Int=25,
                    reporters::Int=50,
                    itermax::Int=250,
                    timesteps::Int=100,
                    scalars::Float64=0.0,
                    scalarmin::Float64=0.0,
                    scalarmax::Float64=0.0,
                    liar_threshold::Float64=0.6,
                    variance_threshold::Float64=0.9,
                    distorter::Bool=false,
                    distort::Float64=0.0,
                    distort_threshold::Float64=0.1,
                    responses::UnitRange{Int}=-1:1,
                    alpha::Float64=0.2,
                    rep_range::UnitRange{Int}=1:25,
                    rep_rand::Bool=false,
                    collude::Float64=0.3,
                    indiscriminate::Bool=true,
                    verbose::Bool=false,
                    conspiracy::Bool=false,
                    allwrong::Bool=false,
                    save_raw_data::Bool=false,
                    algos::Vector{ASCIIString}=["sztorc",
                                                "fixed-variance",
                                                "covariance",
                                                "cokurtosis"],
                    metrics::Vector{ASCIIString}=["beats",
                                                  "liars_bonus",
                                                  "correct",
                                                  "sensitivity",
                                                  "fallout",
                                                  "precision",
                                                  "MCC"],
                    statistics::Vector{ASCIIString}=["mean",
                                                     "stderr"],
                    track::Vector{Symbol}=[:gini,
                                           :MCC,
                                           :correct]) =
            new(events,
                reporters,
                itermax,
                sqrt(itermax),
                timesteps,
                scalars,
                scalarmin,
                scalarmax,
                liar_threshold,
                variance_threshold,
                distorter,
                distort,
                distort_threshold,
                responses,
                alpha,
                int(reporters/10),
                rep_range,
                rep_rand,
                collude,
                indiscriminate,
                verbose,
                conspiracy,
                allwrong,
                save_raw_data,
                algos,
                metrics,
                statistics,
                track)
    end

    Track = Dict{Symbol,Dict{Symbol,Vector{Float64}}}
    Trajectory = Dict{String,Track}

    include("simulate.jl")
    include("complexity.jl")
    include("makedata.jl")
    include("metrics.jl")
    include("plots.jl")
    include("files.jl")

end # module
