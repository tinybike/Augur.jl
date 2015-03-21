using Simulator
using DataFrames
using Dates
using Debug

datafile = "data/sim_2015-03-21T03:16:45.jld"

if ~isinteractive() && length(ARGS) > 0
    datafile = ARGS[1]
end

sim_data = load_data(datafile)
sim = sim_data["sim"]
trajectories = sim_data["trajectories"]

if ~isinteractive()
    for algo in sim.ALGOS
        plot_trajectories(sim,
                          trajectories,
                          sim_data["liar_threshold"],
                          algo,
                          build_title(sim, algo))
    end
end
