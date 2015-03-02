# Augur Simulator

[![Build Status](https://travis-ci.org/AugurProject/Simulator.jl.svg?branch=master)](https://travis-ci.org/AugurProject/Simulator.jl) [![Coverage Status](https://coveralls.io/repos/AugurProject/Simulator.jl/badge.svg)](https://coveralls.io/r/AugurProject/Simulator.jl)

Monte Carlo simulations, statistics and plotting tools for [Augur](http://www.augur.net)'s distributed [consensus algorithm](http://www.augur.net/blog/a-decentralized-lie-detector).  In addition to the Julia packages in REQUIRE, Simulator.jl also needs Python 2.7 and the [pyconsensus](https://github.com/AugurProject/pyconsensus) package.

### Installation

    julia> Pkg.clone("git://github.com/AugurProject/Simulator.jl")

### Usage

    julia> using Simulator

    julia> percent_liars = 0.1:0.1:0.9

    julia> simulation_results = run_simulations(percent_liars)

    julia> plot_simulations(simulation_results)

The simulations are parallelized.  To run parallel simulations using all available cores:

    $ cd test && julia -p `nproc` runtests.jl
