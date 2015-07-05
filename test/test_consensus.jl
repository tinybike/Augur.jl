using Augur
using Base.Test

ɛ = 1e-6

include("setup.jl")

function test_consensus(sim::Simulation)
    println("   - consensus")
    expected = [
        "clusterfeck" => [
            :nonconformity => [ 0.333333, 0.166667, 0.333333, 0.166667, 0.0, 0.0 ],
            :outcomes_final => [ 2.0, 1.5, 1.5, 1.0 ],
            :outcomes_raw => [ 1.7, 1.533333, 1.466667, 1.3 ],
            :certainty => [ 0.7, 0.0, 0.0, 0.7 ],
            :participation => [ 1, 1, 1, 1, 1, 1 ],
            :updated_rep => [ 0.183333, 0.166667, 0.183333, 0.166667, 0.15, 0.15 ],
            :reporter_bonus => [ 0.183333, 0.166667, 0.183333, 0.166667, 0.15, 0.15 ],
        ],
        "hierarchical" => [
            :nonconformity => [ 0.250000, 0.0, 0.250000, 0.0, 0.250000, 0.250000 ],
            :outcomes_final => [ 2.0, 1.5, 1.5, 1.0 ],
            :outcomes_raw => [ 1.65, 1.5, 1.5, 1.35 ],
            :certainty => [ 0.65, 0.0, 0.0, 0.65 ],
            :participation => [ 1, 1, 1, 1, 1, 1 ],
            :updated_rep => [ 0.175, 0.15, 0.175, 0.15, 0.175, 0.175 ],
            :reporter_bonus => [ 0.175, 0.15, 0.175, 0.15, 0.175, 0.175 ],
        ],
        "DBSCAN" => [
            :nonconformity => [ 0.250000, 0.0, 0.250000, 0.0, 0.250000, 0.250000 ],
            :outcomes_final => [ 2.0, 1.5, 1.5, 1.0 ],
            :outcomes_raw => [ 1.65, 1.5, 1.5, 1.35 ],
            :certainty => [ 0.65, 0.0, 0.0, 0.65 ],
            :participation => [ 1, 1, 1, 1, 1, 1 ],
            :updated_rep => [ 0.175, 0.15, 0.175, 0.15, 0.175, 0.175 ],
            :reporter_bonus => [ 0.175, 0.15, 0.175, 0.15, 0.175, 0.175 ],
        ],
        "PCA" => [
            :nonconformity => [ -1.993185, -1.536129, -1.993185, -1.536129, 0.0, 0.0 ],
            :outcomes_final => [ 2.0, 1.5, 1.5, 1.0 ],
            :outcomes_raw => [ 1.7, 1.528238, 1.471762, 1.3 ],
            :certainty => [ 0.7, 0.0, 0.0, 0.7 ],
            :participation => [ 1, 1, 1, 1, 1, 1 ],
            :updated_rep => [ 0.178238, 0.171762, 0.178238, 0.171762, 0.15, 0.15 ],
            :reporter_bonus => [ 0.178238, 0.171762, 0.178238, 0.171762, 0.15, 0.15 ],
        ],
    ]
    for algo in sim.ALGOS
        results = consensus(sim, sim.TEST_REPORTS, sim.TEST_INIT_REP; algo=algo)
        @test_approx_eq_eps results[:nonconformity] expected[algo][:nonconformity] ɛ
        @test_approx_eq_eps results[:outcomes_final] expected[algo][:outcomes_final] ɛ
        @test_approx_eq_eps results[:outcomes_raw] expected[algo][:outcomes_raw] ɛ
        @test_approx_eq_eps results[:certainty] expected[algo][:certainty] ɛ
        @test_approx_eq_eps results[:participation] expected[algo][:participation] ɛ
        @test_approx_eq_eps results[:updated_rep] expected[algo][:updated_rep] ɛ
        @test_approx_eq_eps results[:reporter_bonus] expected[algo][:reporter_bonus] ɛ
    end
end

test_consensus(setup(Simulation())[:sim])
