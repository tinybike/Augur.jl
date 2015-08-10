using Augur
using Base.Test
using Distributions

include("setup.jl")

function test_process_raw_data(sim::Simulation)
    println("   - process_raw_data")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    process_raw_data(sim)
end

function test_reptrack_sums(sim::Simulation)
    println("   - reptrack_sums")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    reptrack_sums(sim)
end

function test_calculate_trajectories(sim::Simulation)
    println("   - calculate_trajectories")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    expected_trajectory = [
        "PCA" => [
            :liars_bonus => [-0.06942541767660715, -0.06942541767660715],
            :liar_rep => [0.6435248607744642, 0.6435248607744642],
        ],
        "hierarchical" => [
            :liars_bonus => [-0.050000000000000044, -0.050000000000000044],
            :liar_rep => [0.6499999999999999, 0.6499999999999999],
        ],
        "cflash" => [
            :liars_bonus => [-0.09999999900000023, -0.09999999900000023],
            :liar_rep => [0.6333333336666667, 0.6333333336666667],
        ],
        "DBSCAN" => [
            :liars_bonus => [-0.050000000000000044, -0.050000000000000044],
            :liar_rep => [0.6499999999999999, 0.6499999999999999],
        ],
    ]
    sim.TIMESTEPS = 2
    sim.ITERMAX = 2
    (A, track) = init_tracking(sim)::Tuple
    raw_data = init_raw_data(sim)::Dict{String,Any}
    for i = 1:sim.ITERMAX
        for algo in sim.ALGOS
            for t = 1:sim.TIMESTEPS
                results = consensus(sim, sim.TEST_REPORTS, sim.TEST_INIT_REP; algo=algo)
                updated_rep = convert(Vector{Float64},
                                      results[:reporter_bonus])
                metrics = compute_metrics(sim,
                                          data,
                                          results[:outcomes_final],
                                          sim.TEST_INIT_REP,
                                          updated_rep)
                track[algo] = track_evolution(sim, metrics, track[algo], t, i)
            end
        end
    end
    trajectory = calculate_trajectories(sim, track)
    for algo in sim.ALGOS
        @test trajectory[algo][:liars_bonus][:mean][1] == expected_trajectory[algo][:liars_bonus][1]
        @test trajectory[algo][:liars_bonus][:mean][2] == expected_trajectory[algo][:liars_bonus][2]
        @test trajectory[algo][:liar_rep][:mean][1] == expected_trajectory[algo][:liar_rep][1]
        @test trajectory[algo][:liar_rep][:mean][2] == expected_trajectory[algo][:liar_rep][2]
    end
end

function test_save_raw_data(sim::Simulation)
    println("   - save_raw_data")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    save_raw_data(sim)
end

function test_init_repbox(sim::Simulation)
    println("   - init_repbox")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    (repbox, repdelta) = init_repbox(sim)
end

function test_init_raw_data(sim::Simulation)
    println("   - init_raw_data")
    raw_data = init_raw_data(sim)::Dict{String,Any}
    @test raw_data["sim"] == sim
    for algo in sim.ALGOS
        @test haskey(raw_data, algo)
        for m in sim.METRICS
            @test haskey(raw_data[algo], m)
            @test haskey(raw_data[algo][m], sim.TIMESTEPS)
            @test isa(raw_data[algo][m][sim.TIMESTEPS], Vector{Float64})
        end
    end
end

function test_track_evolution(sim::Simulation)
    println("   - track_evolution")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    (A, track) = init_tracking(sim)::Tuple
    expected_track = [
        "PCA" => [
            :MCC         => [0.0],
            :beats       => [0.0],
            :correct     => [0.5],
            :liars_bonus => [-0.06942541767660715],
            :liar_rep    => [0.6435248607744642],
            :spearman    => [1.0],
        ],
        "hierarchical" => [
            :MCC         => [0.0],
            :beats       => [0.5],
            :correct     => [0.5],
            :liars_bonus => [-0.050000000000000044],
            :liar_rep    => [0.6499999999999999],
            :spearman    => [0.0],
        ],
        "cflash" => [
            :beats       => [0.0],
            :liars_bonus => [-0.09999999900000023],
            :correct     => [0.5],
            :MCC         => [0.0],
            :liar_rep    => [0.6333333336666667],
            :spearman    => [1.0],
        ],
        "DBSCAN" => [
            :MCC         => [0.0],
            :beats       => [0.5],
            :correct     => [0.5],
            :liars_bonus => [-0.050000000000000044],
            :liar_rep    => [0.6499999999999999],
            :spearman    => [0.0],
        ],
    ]
    t = 1
    i = 1
    for algo in sim.ALGOS
        raw_data = init_raw_data(sim)::Dict{String,Any}
        results = consensus(sim, sim.TEST_REPORTS, sim.TEST_INIT_REP; algo=algo)
        updated_rep = convert(Vector{Float64},
                              results[:reporter_bonus])
        metrics = compute_metrics(sim,
                                  data,
                                  results[:outcomes_final],
                                  sim.TEST_INIT_REP,
                                  updated_rep)::Dict{Symbol,Float64}
        track[algo] = track_evolution(sim, metrics, track[algo], t, i)
        for tr in sim.TRACK
            @test track[algo][tr][t,i] == expected_track[algo][tr][t,i]
        end
    end
end

function test_save_timestep_data(sim::Simulation)
    println("   - save_timestep_data")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    expected_raw_data = (String => Dict{String,Dict{Int,Vector{Float64}}})[
        "PCA" => (String => Dict{Int,Vector{Float64}})[
            "spearman"    => [1=>[1.0]],
            "beats"       => [1=>[0.0]],
            "correct"     => [1=>[0.5]],
            "liar_rep"    => [1=>[0.6435248607744642]],
            "liars_bonus" => [1=>[-0.06942541767660715]],
            "MCC"         => [1=>[0.0]],
        ],
        "hierarchical" => (String => Dict{Int,Vector{Float64}})[
            "spearman"    => [1=>[0.0]],
            "beats"       => [1=>[0.5]],
            "correct"     => [1=>[0.5]],
            "liar_rep"    => [1=>[0.6499999999999999]],
            "liars_bonus" => [1=>[-0.050000000000000044]],
            "MCC"         => [1=>[0.0]],
        ],
        "cflash" => (String => Dict{Int,Vector{Float64}})[
            "spearman"    => [1=>[1.0]],
            "beats"       => [1=>[0.0]],
            "correct"     => [1=>[0.5]],
            "liar_rep"    => [1=>[0.6333333336666667]],
            "liars_bonus" => [1=>[-0.09999999900000023]],
            "MCC"         => [1=>[0.0]],
        ],
        "DBSCAN" => (String => Dict{Int,Vector{Float64}})[
            "spearman"    => [1=>[0.0]],
            "beats"       => [1=>[0.5]],
            "correct"     => [1=>[0.5]],
            "liar_rep"    => [1=>[0.6499999999999999]],
            "liars_bonus" => [1=>[-0.050000000000000044]],
            "MCC"         => [1=>[0.0]],
        ],
    ]
    t = 1
    for algo in sim.ALGOS
        raw_data = init_raw_data(sim)::Dict{String,Any}
        @test raw_data["sim"] == sim
        @test haskey(raw_data, algo)
        for m in sim.METRICS
            @test haskey(raw_data[algo], m)
            @test haskey(raw_data[algo][m], sim.TIMESTEPS)
            @test isa(raw_data[algo][m][sim.TIMESTEPS], Vector{Float64})
        end
        results = consensus(sim, sim.TEST_REPORTS, sim.TEST_INIT_REP; algo=algo)
        updated_rep = convert(Vector{Float64},
                              results[:reporter_bonus])
        metrics = compute_metrics(sim,
                                  data,
                                  results[:outcomes_final],
                                  sim.TEST_INIT_REP,
                                  updated_rep)::Dict{Symbol,Float64}
        raw_data = save_timestep_data(sim, raw_data, metrics, algo, t)
        @test raw_data["sim"] == sim
        @test haskey(raw_data, algo)
        for m in sim.METRICS
            @test haskey(raw_data[algo], m)
            @test isa(raw_data[algo][m], Dict{Int,Vector{Float64}})
            @test isa(raw_data[algo][m][t], Vector{Float64})
            @test length(raw_data[algo][m][t]) == 1
            @test raw_data[algo][m] == expected_raw_data[algo][m]
        end
    end
end

function test_simulate(sim::Simulation)
    println("   - simulate")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    sim.ITERMAX = 5
    sim.TIMESTEPS = 2
    sim = preprocess(sim)
    results = simulate(sim)
    @test haskey(results, "trajectory")
    for algo in sim.ALGOS
        @test haskey(results, algo)
        for s in sim.STATISTICS
            @test haskey(results[algo], string(s))
            for m in sim.METRICS
                @test haskey(results[algo][s], m)
                @test isa(results[algo][s][m], Float64)
            end
        end
        @test haskey(results["trajectory"], algo)
        for tr in sim.TRACK
            @test haskey(results["trajectory"][algo], tr)
            for s in sim.STATISTICS
                @test haskey(results["trajectory"][algo][tr], symbol(s))
                @test isa(results["trajectory"][algo][tr][symbol(s)],
                          Vector{Float64})
            end
        end
    end
end

function test_exclude(sim::Simulation)
    println("   - exclude")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    exclude(sim, (:MCC, :sensitivity, :fallout, :precision))
end

function test_preprocess(sim::Simulation)
    println("   - preprocess")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    sim = preprocess(sim)
end

function test_run_simulations(sim::Simulation)
    println("   - run_simulations")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    run_simulations(0.5:0.6, sim, parallel=true)
end

setup(sim; reset=true)

# test_exclude(sim)
# test_preprocess(sim)
test_init_raw_data(sim)
# test_init_repbox(sim)
test_track_evolution(sim)
test_save_timestep_data(sim)
test_calculate_trajectories(sim)
# test_save_raw_data(sim)
# test_reptrack_sums(sim)
# test_process_raw_data(sim)
# test_simulate(sim)
# test_run_simulations(sim)
