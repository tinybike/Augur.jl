# Augur Simulator

Monte Carlo simulations, statistics and plotting tools for [Augur](http://www.augur.net)'s distributed [consensus algorithm](http://www.augur.net/blog/a-decentralized-lie-detector).  In addition to the Julia packages in REQUIRE, Simulator.jl also needs Python 2.7 and the [pyconsensus](https://github.com/AugurProject/pyconsensus) package.

### Installation

    julia> Pkg.clone("git://github.com/AugurProject/Simulator.jl")

### Usage

The simulations are parallelized.  To run using all available cores:

    $ cd test
    $ julia -p `nproc` test/tinker.jl

### NYI

- label pairs, triples, quadruples
- mix conspiracy with regular collusion
- check reward/vote slopes for scalars
- port "winning" algo to Serpent
- plot simulation size vs # components
- fit reputation distribution to pareto (or lognormal) and track scaling exponent
- multimodal event detection
