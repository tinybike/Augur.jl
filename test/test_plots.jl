using Augur
using Base.Test
using Distributions
using PyCall
using DataFrames
using Gadfly

include("setup.jl")

@pyimport pyconsensus

function test_build_dataframe(sim_data)
    println("   - test_build_dataframe")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    build_dataframe(sim_data)
end

function test_build_dataframe(sim_data, metric)
    println("   - test_build_dataframe")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    build_dataframe(sim_data, metric)
end

function test_plot_dataframe(df, title)
    println("   - test_plot_dataframe")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    plot_dataframe(df, title)
end

function test_plot_dataframe(df, title, metric)
    println("   - test_plot_dataframe")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    plot_dataframe(df, title, metric)
end

function test_plot_median_rep(sim_data, metric, algo)
    println("   - test_plot_median_rep")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    plot_median_rep(sim_data, metric, algo)
end

function test_capitalize(algo)
    println("   - test_capitalize")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    capitalize(algo)
end

function test_build_title(sim)
    println("   - test_build_title")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    build_title(sim)
end

function test_build_title(sim, algo)
    println("   - test_build_title")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    build_title(sim, algo)
end

function test_plot_trajectories(sim, trajectories, liar_thresholds, title)
    println("   - test_plot_trajectories")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    plot_trajectories(sim, trajectories, liar_thresholds, title)
end

function test_plot_trajectories(sim, trajectories, liar_thresholds, algo, title, tr)
    println("   - test_plot_trajectories")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    plot_trajectories(sim, trajectories, liar_thresholds, algo, title, tr)
end

function test_plot_simulations(sim_data)
    println("   - test_plot_simulations")
    data = setup(sim)::Dict{Symbol,Any}
    sim = pop!(data, :sim)
    plot_simulations(sim_data)
end

test_build_dataframe(sim_data)
test_build_dataframe(sim_data, metric)
test_plot_dataframe(df, title)
test_plot_dataframe(df, title, metric)
test_plot_median_rep(sim_data, metric, algo)
test_capitalize(algo)
test_build_title(sim)
test_build_title(sim, algo)
test_plot_trajectories(sim, trajectories, liar_thresholds, title)
test_plot_trajectories(sim, trajectories, liar_thresholds, algo, title, tr)
test_plot_simulations(sim_data)
