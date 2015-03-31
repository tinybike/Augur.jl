using Simulator
using DataFrames
using Dates
using Debug

datafile = "data/sim_2015-03-31T00:33:51.jld"

if ~isinteractive() && length(ARGS) > 0
    datafile = ARGS[1]
end

sim_data = load_data(datafile)
sim = sim_data["sim"]
trajectories = sim_data["trajectories"]

if ~isinteractive()
    plot_simulations(sim_data)

    # Time series plots only
    # sim = pop!(sim_data, "sim")
    # for algo in sim.ALGOS
    #     trajectory_title = build_title(sim, algo)

    #     # Stacked plots
    #     plot_trajectories(sim,
    #                       trajectories,
    #                       sim_data["liar_threshold"],
    #                       algo,
    #                       trajectory_title)

    #     # Separate tracking metrics
    #     for tr in sim.TRACK
    #         plot_trajectories(sim,
    #                           trajectories,
    #                           sim_data["liar_threshold"],
    #                           algo,
    #                           trajectory_title,
    #                           tr)
    #     end
    # end
end
