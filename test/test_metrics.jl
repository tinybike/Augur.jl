using Simulator
using Base.Test

include("setup.jl")

function test_compute_metrics(sim::Simulation)
    println("   - compute_metrics")
    expected_metrics = (String => Dict{Symbol,Float64})[
        "PCA" => (Symbol => Float64)[
            :spearman    => 1.0,
            :true_rep    => 0.35647513922553575,
            :MCC         => 0.0,
            :correct     => 0.5,
            :precision   => 0.6666666666666666,
            :fallout     => 1.0,
            :gap         => -0.2870497215489285,
            :beats       => 0.0,
            :gini        => 0.037650092817023584,
            :liars_bonus => -0.06942541767660715,
            :liar_rep    => 0.6435248607744642,
            :sensitivity => 1.0,
        ],
        # "clusterfeck" => (Symbol => Float64)[
        #     :spearman    => 1.0,
        #     :true_rep    => 0.373469387755102,
        #     :MCC         => 0.0,
        #     :correct     => 0.5,
        #     :precision   => 0.6666666666666666,
        #     :fallout     => 1.0,
        #     :gap         => -0.2530612244897959,
        #     :beats       => 0.0,
        #     :gini        => 0.0435374149659864,
        #     :liars_bonus => -0.12040816326530623,
        #     :liar_rep    => 0.6265306122448979,
        #     :sensitivity => 1.0,
        # ],
        "clusterfeck" => (Symbol => Float64)[
            :spearman    => 1.0,
            :true_rep    => 0.36666666633333334,
            :MCC         => 0.0,
            :correct     => 0.5,
            :precision   => 0.6666666666666666,
            :fallout     => 1.0,
            :gap         => -0.26666666733333333,
            :beats       => 0.0,
            :gini        => 0.04444444400000003,
            :liars_bonus => -0.09999999900000023,
            :liar_rep    => 0.6333333336666667,
            :sensitivity => 1.0,
        ],
        "hierarchical" => (Symbol => Float64)[
            :spearman    => 0.0,
            :true_rep    => 0.35,
            :MCC         => 0.0,
            :correct     => 0.5,
            :precision   => 0.6666666666666666,
            :fallout     => 1.0,
            :gap         => -0.29999999999999993,
            :beats       => 0.5,
            :gini        => 0.03333333333333299,
            :liars_bonus => -0.050000000000000044,
            :liar_rep    => 0.6499999999999999,
            :sensitivity => 1.0,
        ],
    ]
    data = setup(sim)::Dict{Symbol,Any}
    for algo in sim.ALGOS
        results = consensus(sim.TEST_REPORTS, sim.TEST_INIT_REP; alpha=sim.ALPHA, algo=algo)
        updated_rep = convert(Vector{Float64},
                              results[:agents][:reporter_bonus])
        metrics = compute_metrics(sim,
                                  data,
                                  results[:events][:outcomes_final],
                                  sim.TEST_INIT_REP,
                                  updated_rep)
        @test metrics == expected_metrics[algo]
    end
end

test_compute_metrics(sim)
