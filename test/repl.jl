using Augur
using DataFrames
using Dates
using Distributions

include("setup.jl")

sim = preprocess(setup(Simulation())[:sim])

sim.VERBOSE = false

sim.LIAR_THRESHOLD = 0.65

sim.EVENTS = 100
sim.REPORTERS = 250
sim.ITERMAX = 100
sim.TIMESTEPS = 250

sim.SCALARS = 0.0
sim.REP_RAND = true
sim.REP_DIST = Pareto(3.0)

sim.BRIDGE = false
sim.MARKET_DIST = Pareto(3.0)
sim.CORRUPTION = 0.75
sim.RARE = 1e-5
sim.MONEYBIN = first(find(pdf(sim.MARKET_DIST, 1:1e4) .< sim.RARE))

sim.ALPHA = 0.1
sim.CONSPIRACY = false
sim.LABELSORT = true
sim.HISTOGRAM = false

sim.ALGOS = [
   "PCA",
   "cflash",
   "k-means",
   "hierarchical",
   "fixed-variance",
]

sim = preprocess(sim)

raw_data = (String => Any)[ "sim" => sim ]
timesteps = (sim.SAVE_RAW_DATA) ? 1:sim.TIMESTEPS : sim.TIMESTEPS
for algo in sim.ALGOS
    raw_data[algo] = Dict{String,Any}()
    for m in [sim.METRICS, "components"]
        raw_data[algo][m] = Dict{Int,Vector{Float64}}()
        for t in timesteps
            raw_data[algo][m][t] = Float64[]
        end
    end
end
track = Dict{String,Dict{Symbol,Matrix{Float64}}}()
A = Dict{String,Any}()
for algo in sim.ALGOS
    A[algo] = Dict{String,Any}()
    track[algo] = Dict{Symbol,Matrix{Float64}}()
    for tr in sim.TRACK
        track[algo][tr] = zeros(sim.TIMESTEPS, sim.ITERMAX)
    end
end

# Reputation time series (repbox):
# - column t is the reputation vector at time t
# - third axis = iteration
repbox = Dict{String,Array{Float64,3}}()
repdelta = Dict{String,Array{Float64,3}}()
for algo in sim.ALGOS
    repbox[algo] = zeros(sim.REPORTERS, sim.TIMESTEPS, sim.ITERMAX)
    repdelta[algo] = zeros(sim.REPORTERS, sim.TIMESTEPS, sim.ITERMAX)
end

sort_by_label = []
sort_by_rep = []
tokens = {}
metrics = {}
init_rep = []
reputation = []
timesteps = 1:sim.TIMESTEPS

if ~sim.TESTING
    reporters = create_reporters(sim)
else
    trues = find(sim.TEST_REPORTERS .== "true")
    distorts = find(sim.TEST_REPORTERS .== "distort")
    liars = find(sim.TEST_REPORTERS .== "liar")
    num_trues = length(trues)
    num_distorts = length(distorts)
    num_liars = length(liars)
    reporters = (Symbol => Any)[
        :reporters => sim.TEST_REPORTERS,
        :trues => trues,
        :distorts => distorts,
        :liars => liars,
        :num_trues => num_trues,
        :num_distorts => num_distorts,
        :num_liars => num_liars,
        :honesty => nothing,
        :aux => nothing,
    ]
end

i = t = 1
data = convert(Vector{Any}, zeros(sim.TIMESTEPS));
for i = 1:sim.ITERMAX

    # Initialize reporters and reputation
    if ~sim.TESTING
        init_rep = init_reputation(sim)
    else
        init_rep = sim.TEST_INIT_REP
    end
    metrics = Dict{Symbol,Float64}()

    # Create datasets (identical for each algorithm)
    if ~sim.TESTING
        for t = 1:sim.TIMESTEPS
            data[t] = generate_data(sim, reporters)
        end
    else
        data[t] = (Symbol => Any)[
            :reporters => reporters[:reporters],
            :honesty => reporters[:honesty],
            :correct_answers => sim.TEST_CORRECT_ANSWERS,
            :distorts => reporters[:distorts],
            :reports => sim.TEST_REPORTS,
            :aux => nothing,
            :num_distorts => reporters[:num_distorts],
            :num_trues => reporters[:num_trues],
            :num_liars => reporters[:num_liars],
            :trues => reporters[:trues],
            :liars => reporters[:liars],
        ]
    end
    tokens = (Symbol => Float64)[
        :trues => sum(init_rep .* (reporters[:reporters] .== "true")),
        :liars => sum(init_rep .* (reporters[:reporters] .== "liar")),
        :distorts => sum(init_rep .* (reporters[:reporters] .== "distort")),
    ]
    # sort_by_label = sortperm(reporters[:reporters])
    # sort_by_rep = sortperm(init_rep)
    # initdf = DataFrame(
    #     label_sort_by_label=reporters[:reporters][sort_by_label],
    #     reputation_sort_by_label=init_rep[sort_by_label],
    #     label_sort_by_rep=reporters[:reporters][sort_by_rep],
    #     reputation_sort_by_rep=init_rep[sort_by_rep],
    # )
    reputation = copy(init_rep)
    for algo in sim.ALGOS
        for t = timesteps
            reputation = (t == 1) ? init_rep : A[algo][:updated_rep]
            repbox[algo][:,t,i] = reputation
            repdelta[algo][:,t,i] = reputation - repbox[algo][:,1,i]
            A[algo] = consensus(sim, data[t][:reports], reputation; algo=algo)
            metrics = compute_metrics(
                sim,
                data[t],
                A[algo][:outcomes_final],
                reputation,
                A[algo][:updated_rep],
            )
            for tr in sim.TRACK
                track[algo][tr][t,i] = metrics[tr]
            end
        end
    end
end

df = DataFrame(honesty=data[1][:reporters],
               fixed_variance=repdelta["fixed-variance"][:,end,1],
               cflash=repdelta["cflash"][:,end,1],
               PCA=repdelta["PCA"][:,end,1],
               k_means=repdelta["k-means"][:,end,1],
               hierarchical=repdelta["hierarchical"][:,end,1])

trajectory = Trajectory()
for algo in sim.ALGOS
    trajectory[algo] = Track()
    for tr in sim.TRACK
        trajectory[algo][tr] = (Symbol => Vector{Float64})[
            :mean => mean(track[algo][tr], 2)[:],
            :stderr => std(track[algo][tr], 2)[:] / sim.SQRTN,
        ]
    end
end

mean_repdelta = Dict{String,Matrix{Float64}}()
std_repdelta = Dict{String,Matrix{Float64}}()
for algo in sim.ALGOS
    mean_repdelta[algo] = squeeze(sum(repdelta[algo], 3), 3)
    std_repdelta[algo] = squeeze(std(repdelta[algo], 3), 3)
end

mean_rep_liars = Dict{String,Vector{Float64}}()
std_rep_liars = Dict{String,Vector{Float64}}()
for algo in sim.ALGOS
    mean_rep_liars[algo] = vec(sum(mean_repdelta[algo][reporters[:liars],:],1))
    std_rep_liars[algo] = vec(std(std_repdelta[algo][reporters[:liars],:],1))
end
