using Augur
using Base.Test
using DataFrames
using Dates

include("setup.jl")

sim = preprocess(setup(Simulation())[:sim])

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
for i = 1:sim.ITERMAX

    # Initialize reporters and reputation
    if ~sim.TESTING
        init_rep = init_reputation(sim)
    else
        init_rep = sim.TEST_INIT_REP
    end
    metrics = Dict{Symbol,Float64}()

    # Create datasets (identical for each algorithm)
    data = convert(Vector{Any}, zeros(sim.TIMESTEPS));
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

    sort_by_label = sortperm(reporters[:reporters])
    sort_by_rep = sortperm(init_rep)
    initdf = DataFrame(
        label_sort_by_label=reporters[:reporters][sort_by_label],
        reputation_sort_by_label=init_rep[sort_by_label],
        label_sort_by_rep=reporters[:reporters][sort_by_rep],
        reputation_sort_by_rep=init_rep[sort_by_rep],
    )
    reputation = copy(init_rep)

    for algo in sim.ALGOS
        for t = timesteps
            reputation = (t == 1) ? init_rep : A[algo][:reporter_bonus]
            repbox[algo][:,t,i] = reputation
            repdelta[algo][:,t,i] = reputation - repbox[algo][:,1,i]

            A[algo] = consensus(sim, data[t][:reports], reputation; algo=algo)

            updated_rep = convert(Vector{Float64},
                                  A[algo][:reporter_bonus])
            metrics = compute_metrics(
                sim,
                data[t],
                A[algo][:outcomes_final],
                reputation,
                updated_rep,
            )
            for tr in sim.TRACK
                track[algo][tr][t,i] = metrics[tr]
            end
        end
    end
end

@test round(A["DBSCAN"][:reporter_bonus], 6) == [ 0.175, 0.15, 0.175, 0.15, 0.175, 0.175 ]
