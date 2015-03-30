using Dates
using PyPlot
using QuantEcon: meshgrid

function plot_reptrack(sim_data::Dict{String,Any})
    sim = sim_data["sim"]
    for algo in sim.ALGOS
        for (i, rt) in enumerate(sim_data["reptracks"])
            reptrack = rt[algo]["mean"]::Matrix{Float64}
            fig = PyPlot.figure(figsize=(8, 6))
            ax = fig[:gca](projection="3d", xlabel="time", ylabel="reporter")
            xgrid, ygrid = meshgrid([1:sim.TIMESTEPS], [1:sim.REPORTERS])
            ax[:plot_surface](xgrid, ygrid, reptrack,
                              rstride=1, cstride=1,
                              cmap=ColorMap("jet"),
                              alpha=0.7,
                              linewidth=0.25)
            pl_file = "plots/rt_" * repr(i) * "_" * algo * "_" * repr(now()) * ".png"
            PyPlot.savefig(pl_file)
            print_with_color(:white, "Saved to ")
            print_with_color(:cyan, "$pl_file\n")
        end
    end
end
