using Augur
using Base.Test

ɛ = 1e-12

include("setup.jl")

function test_create_reporters()
    println("   - create_reporters")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    create_reporters(sim)
end

function test_generate_answers()
    println("   - generate_answers")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    generate_answers(sim, data)
end

function test_populate_markets()
    println("   - populate_markets")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    populate_markets(sim)
end

function test_generate_reports()
    println("   - generate_reports")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    generate_reports(sim, data)
end

function test_generate_data()
    println("   - generate_data")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    generate_data(sim, data)
end

function test_init_reputation()
    println("   - init_population")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    init_reputation(sim)
end

function test_normalize()
    println("   - normalize")
    test_vector = [1.0, 2.0, 3.0, 4.0, 5.0]
    normalized_vector = normalize(test_vector)
    @test_approx_eq_eps sum(normalized_vector) 1.0 ɛ
end

test_create_reporters()
test_generate_answers()
test_populate_markets()
test_generate_reports()
test_generate_data()
test_init_reputation()
test_normalize()
