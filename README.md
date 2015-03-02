# Simulator

[![Build Status](https://travis-ci.org/AugurProject/Simulator.jl.svg?branch=master)](https://travis-ci.org/AugurProject/Simulator.jl) [![Coverage Status](https://coveralls.io/repos/AugurProject/Simulator.jl/badge.png)](https://coveralls.io/r/AugurProject/Simulator.jl)

Monte Carlo simulations, statistics and plotting for [Augur's](http://www.augur.net) [decentralized oracle](http://www.augur.net/blog/a-decentralized-lie-detector).  In addition to the Julia packages in REQUIRE, Simulator also needs Python 2.7 and the [pyconsensus](https://github.com/AugurProject/pyconsensus) package.

### Installation

    julia> Pkg.clone("git://github.com/AugurProject/Simulator.jl")

### Usage

    julia> using Simulator

    julia> simulation_results = run_simulations(0.1:0.1:0.9)

    julia> plot_simulations(simulation_results)

The simulations are parallelized.  To run simulations in parallel on a 4 core machine:

    $ cd test && julia -p 4 runtests.jl
