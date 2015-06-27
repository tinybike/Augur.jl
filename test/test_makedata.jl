using Simulator
using Base.Test
using Distributions
using PyCall

include("setup.jl")

@pyimport pyconsensus

function test_create_reporters()
    println("   - test_create_reporters")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    create_reporters(sim)
end

function test_generate_answers()
    println("   - test_generate_answers")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    generate_answers(sim)
end

function test_populate_markets()
    println("   - test_populate_markets")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    populate_markets(sim)
end

function test_generate_reports()
    println("   - test_generate_reports")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    generate_reports(sim)
end

function test_generate_data()
    println("   - test_generate_data")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    generate_data(sim)
end

function test_init_reputation()
    println("   - test_init_population")
    data = setup(Simulation(); reset=true)
    sim = pop!(data, :sim)
    init_reputation(sim)
end

function test_normalize()
    println("   - test_normalize")
    test_vector = [1.0, 2.0, 3.0, 4.0, 5.0]
    normalized_vector = normalize(test_vector)
    @test_approx_eq sum(normalized_vector) 1.0
end

test_create_reporters()
test_generate_answers()
test_populate_markets()
test_generate_reports()
test_generate_data()
test_init_reputation()
test_normalize()
