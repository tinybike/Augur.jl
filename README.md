# Augur Simulator

[![Build Status](https://travis-ci.org/AugurProject/Augur.jl.svg?branch=master)](https://travis-ci.org/AugurProject/Augur.jl) [![Coverage Status](https://coveralls.io/repos/AugurProject/Augur.jl/badge.svg)](https://coveralls.io/r/AugurProject/Augur.jl) [![Augur](http://pkg.julialang.org/badges/Augur_0.3.svg)](http://pkg.julialang.org/?pkg=Augur&ver=release)

Monte Carlo simulations, statistics and plotting tools for the [Augur](http://www.augur.net) [event consensus algorithm](http://www.augur.net/blog/building-a-better-lie-detector).

### Installation

    julia> Pkg.add("Augur")

### Usage

Run simulations with default settings using all available cores:

    $ julia -p `nproc` test/controller.jl

Simulation results are automatically saved to `test/data`.  If `sim.SAVE_RAW_DATA = true`, in addition to the output data, full time traces will be saved to `test/data/raw`.  (Caution: this option both slows down the simulations and requires considerable storage space to store the results.)

Augur.jl includes plotters written for PyPlot and Gadfly.  To generate plots, just specify `pyplot` or `gadfly` when you run the simulations:

    $ julia -p `nproc` test/controller.jl pyplot

Plots are saved to `test/plots`.

### Tests

Unit tests are included with Augur.jl, and can be run from the `test/runtests.jl` script:

    $ julia test/runtests.jl
