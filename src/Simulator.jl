module Simulator

    using Dates
    using Distributions
    using PyCall
    using HDF5, JLD

    export
        Simulation,
        Trajectory,
        Track,
        generate_data,
        simulate,
        run_simulations,
        plot_simulations,
        plot_overlay,
        build_title,
        plot_trajectories,
        load_data,
        save_data,
        complexity,
        load_time_elapsed,
        save_time_elapsed,
        plot_time_elapsed,
        plot_reptrack,
        infostring,
        exclude,
        preprocess,
        reputation_distribution,
        create_reporters,
        init_reputation,
        compute_metrics,
        reptrack_sums,
        init_raw_data,
        process_raw_data,
        calculate_trajectories,
        save_raw_data,
        print_oracle_output,
        print_repbox,
        init_repbox,
        init_tracking

    type Simulation

        TESTING::Bool
        TEST_REPORTERS::Vector{ASCIIString}
        TEST_INIT_REP::Vector{Float64}
        TEST_CORRECT_ANSWERS::Vector{Float64}
        TEST_REPORTS::Matrix{Float64}

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
        RESPONSES::Range

        # Reputation update smoothing parameter
        ALPHA::Float64

        # Allowed initial reputation values and whether randomized
        REP_BINS::Int
        REP_RAND::Bool

        # Initial reputation sampling distribution
        REP_DIST::Distribution

        # Bridge=true if the reporters take into account the cash markets
        # when reporting, false if they ignore it (ideal case)
        BRIDGE::Bool

        # Market size, price, and overlap distributions
        MARKET_DIST::Distribution
        PRICE_DIST::Distribution
        OVERLAP_DIST::Distribution

        # Corruption: probability of an "honest" reporter switching his report
        # to a lie at market size = MONEYBIN (where the MARKET_SIZE PDF drops
        # below RARE)
        RARE::Float64
        MONEYBIN::Float64
        CORRUPTION::Float64

        # Collusion: 0.2 => 20% chance liar will copy another user
        # (only other liars unless INDISCRIMINATE=true)
        COLLUDE::Float64
        INDISCRIMINATE::Bool
        VERBOSE::Bool
        CONSPIRACY::Bool
        NUM_CONSPIRACIES::Int
        ALLWRONG::Bool

        # Maximum power included in "virial" algo multibody expansion
        VIRIALMAX::Int

        # If true, sort by liar/true/distort label
        LABELSORT::Bool

        # Save data at every timestep (uses lots of disk space)
        SAVE_RAW_DATA::Bool

        # Calculate reputation histograms
        HISTOGRAM::Bool

        # Number of components to include (e.g., big-five algorithm)
        MAX_COMPONENTS::Int

        # Preset (instead of randomized) data
        PRESET::Bool

        SURFACE::Bool
        PRESET_DATA::Dict{Symbol,Any}

        # Event resolution algorithms to test, metrics used to evaluate them,
        # and statistics of these metrics to calculate
        ALGOS::Vector{ASCIIString}
        METRICS::Vector{ASCIIString}
        STATISTICS::Vector{ASCIIString}

        # Tracking statistics for time series analysis
        TRACK::Vector{Symbol}

        AXIS_LABELS::Dict{Symbol,String}

        Simulation(;testing::Bool=false,
                    test_reporters::Vector{ASCIIString}=(ASCIIString)[],
                    test_init_rep::Vector{Float64}=(Float64)[],
                    test_correct_answers::Vector{Float64}=(Float64)[],
                    test_reports::Matrix{Float64}=Array(Float64,2,2),
                    events::Int=50,
                    reporters::Int=100,
                    itermax::Int=250,
                    timesteps::Int=200,
                    scalars::Float64=0.0,
                    scalarmin::Float64=0.0,
                    scalarmax::Float64=0.0,
                    liar_threshold::Float64=0.6,
                    variance_threshold::Float64=0.9,
                    distorter::Bool=false,
                    distort::Float64=0.0,
                    distort_threshold::Float64=0.1,
                    responses::Range=1:0.5:2,
                    alpha::Float64=0.2,
                    rep_rand::Bool=false,
                    rep_dist::Distribution=Uniform(),
                    bridge::Bool=false,
                    market_dist::Distribution=Uniform(),
                    price_dist::Distribution=Uniform(),
                    overlap_dist::Distribution=Uniform(),
                    rare::Float64=1e-5,
                    corruption::Float64=0.5,
                    collude::Float64=0.3,
                    indiscriminate::Bool=true,
                    verbose::Bool=false,
                    conspiracy::Bool=false,
                    num_conspiracies::Int=1,
                    allwrong::Bool=false,
                    virialmax::Int=8,
                    labelsort::Bool=false,
                    save_raw_data::Bool=false,
                    histogram::Bool=false,
                    max_components::Int=5,
                    preset::Bool=false,
                    surface::Bool=false,
                    preset_data::Dict{Symbol,Any}=Dict{Symbol,Any}(),
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
            new(testing,
                test_reporters,
                test_init_rep,
                test_correct_answers,
                test_reports,
                events,
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
                rep_rand,
                rep_dist,
                bridge,
                market_dist,
                price_dist,
                overlap_dist,
                rare,
                first(find(pdf(market_dist, 1:1e4) .< rare)),
                corruption,
                collude,
                indiscriminate,
                verbose,
                conspiracy,
                num_conspiracies,
                allwrong,
                virialmax,
                labelsort,
                save_raw_data,
                histogram,
                max_components,
                preset,
                surface,
                preset_data,
                algos,
                metrics,
                statistics,
                track,
                (Symbol => String)[
                    :MCC => "Matthews correlation coefficient",
                    :correct => "% answers determined correctly",
                    :beats => "beats",
                    :liars_bonus => "liars' bonus",
                    :spearman => "Spearman's rho",
                    :liar_rep => "% Reputation held by liars",
                    :true_rep => "% Reputation held by honest reporters",
                    :gini => "Gini coefficient",
                    :gap => "% Reputation gap",
                    :sensitivity => "sensitivity (true positive rate)",
                    :precision => "precision",
                    :fallout => "fall-out (false positive rate)",
                ])
    end

    Track = Dict{Symbol,Dict{Symbol,Vector{Float64}}}
    Trajectory = Dict{String,Track}

    normalize{T<:Real}(v::Vector{T}) = vec(v) / sum(v)
    normalize{T<:Real}(v::Matrix{T}) = normalize(vec(v))

    include("simulate.jl")
    include("complexity.jl")
    include("makedata.jl")
    include("metrics.jl")
    include("plots.jl")
    # include("pyplots.jl")
    include("files.jl")

end # module
