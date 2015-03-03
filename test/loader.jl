using Simulator

EXAMPLE = "data/sim_2015-03-02T05:56:36.jld"

function load_and_plot_data(datafile::String)
    println("Loading $datafile...")
    plot_simulations(load_data(datafile))
end

datafile = (isinteractive() || length(ARGS) == 0) ? EXAMPLE : ARGS[1]

load_and_plot_data("$datafile")
