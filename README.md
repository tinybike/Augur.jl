# Augur Simulator

[![Build Status](https://travis-ci.org/AugurProject/Augur.jl.svg?branch=master)](https://travis-ci.org/AugurProject/Augur.jl) [![Coverage Status](https://coveralls.io/repos/AugurProject/Augur.jl/badge.svg)](https://coveralls.io/r/AugurProject/Augur.jl)

Monte Carlo simulations, statistics and plotting tools for the [Augur](http://www.augur.net) [event consensus algorithm](http://www.augur.net/blog/building-a-better-lie-detector).

### Installation

    julia> Pkg.add("Augur")

### Usage

The simulations are parallelized.  To run using all available cores:

    $ julia -p `nproc` test/tinker.jl

To run unit tests:

    $ julia test/runtests.jl
