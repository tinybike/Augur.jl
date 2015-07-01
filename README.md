# Augur Simulator

Monte Carlo simulations, statistics and plotting tools for [Augur](http://www.augur.net)'s [event consensus algorithm](http://www.augur.net/blog/building-a-better-lie-detector).

### Installation

    julia> Pkg.clone("git://github.com/AugurProject/Simulator.jl")

### Usage

The simulations are parallelized.  To run using all available cores:

    $ julia -p `nproc` test/tinker.jl

To run unit tests:

    $ julia test/runtests.jl
