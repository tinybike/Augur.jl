function create_reporters(sim::Simulation)
    if sim.DISTORTER
        distort_threshold = sim.LIAR_THRESHOLD + sim.DISTORT_THRESHOLD
        distort_threshold <= 1.0 || throw(BoundsError())
    else
        distort_threshold = sim.LIAR_THRESHOLD
    end

    # Generate artificial "true, distort, liar" list
    honesty = sort(rand(sim.REPORTERS))
    reporters = fill("", sim.REPORTERS)
    reporters[honesty .>= distort_threshold] = "true"
    reporters[sim.LIAR_THRESHOLD .< honesty .< distort_threshold] = "distort"
    reporters[honesty .<= sim.LIAR_THRESHOLD] = "liar"

    trues = find(reporters .== "true")
    distorts = find(reporters .== "distort")
    liars = find(reporters .== "liar")
    num_trues = length(trues)
    num_distorts = length(distorts)
    num_liars = length(liars)

    while num_trues == 0 || num_liars == 0
        honesty = rand(sim.REPORTERS)
        reporters = fill("", sim.REPORTERS)
        reporters[honesty .>= distort_threshold] = "true"
        reporters[sim.LIAR_THRESHOLD .< honesty .< distort_threshold] = "distort"
        reporters[honesty .<= sim.LIAR_THRESHOLD] = "liar"
        trues = find(reporters .== "true")
        distorts = find(reporters .== "distort")
        liars = find(reporters .== "liar")
        num_trues = length(trues)
        num_distorts = length(distorts)
        num_liars = length(liars)
    end

    (Symbol => Any)[
        :reporters => reporters,
        :trues => trues,
        :distorts => distorts,
        :liars => liars,
        :num_trues => num_trues,
        :num_distorts => num_distorts,
        :num_liars => num_liars,
        :honesty => honesty,
        :aux => nothing,
    ]
end

# - Generate the correct answer for each event.
# - Also generate a vector of "corrupt" answers, which reporters may be swayed
#   by money to report.  The corrupt answers are assigned at random, so they
#   are not always incorrect.
function generate_answers(sim::Simulation, data::Dict{Symbol,Any})
    data[:correct_answers] = convert(Vector{Float64}, rand(sim.RESPONSES, sim.EVENTS))
    if sim.BRIDGE
        data[:corrupt_answers] = convert(Vector{Float64}, rand(sim.RESPONSES, sim.EVENTS))
    end
    if sim.SCALARS > 0
        data[:stepsize] = 0.00001
        data[:scalarmask] = rand(sim.EVENTS) .< sim.SCALARS
        data[:scalarmin] = rand(sim.SCALARMIN:data[:stepsize]:sim.SCALARMAX, sim.EVENTS) .* data[:scalarmask]
        data[:scalarmax] = zeros(sim.EVENTS)
        for i = 1:sim.EVENTS
            if data[:scalarmask][i]
                data[:scalarmax][i] = rand(data[:scalarmin][i]:data[:stepsize]:sim.SCALARMAX)
            end
        end
        data[:scalarmax] .*= data[:scalarmask]
        for i = 1:sim.EVENTS
            if data[:scalarmask][i]
                data[:correct_answers][i] = rand(data[:scalarmin][i]:data[:stepsize]:data[:scalarmax][i])
                if sim.BRIDGE
                    data[:corrupt_answers][i] = rand(data[:scalarmin][i]:data[:stepsize]:data[:scalarmax][i])
                end
            end
        end
        if sim.VERBOSE
            display([data[:scalarmask] data[:scalarmin] data[:scalarmax]])
            println("")
            display(data[:correct_answers])
            println("")
            println("% scalars: ", sum(data[:scalarmask]) / sim.EVENTS)
        end
    end
    data
end

# Assign each event a size and price in the pre-event cash market,
# and the amount of overlap between the reporters and traders
# (note: price & overlap not yet used)
function populate_markets(sim::Simulation)
    market_size = rand(sim.MARKET_DIST, sim.EVENTS)
    (Symbol => Vector{Float64})[
        :size => market_size / sim.MONEYBIN,
        :price => rand(sim.PRICE_DIST, sim.EVENTS),
        :overlap => rand(sim.OVERLAP_DIST, sim.EVENTS),
    ]
end

function generate_reports(sim::Simulation, data::Dict{Symbol,Any})

    # True: always report correct answer
    data[:reports] = zeros(sim.REPORTERS, sim.EVENTS)
    data[:reports][data[:trues],:] = convert(
        Matrix{Float64},
        repmat(data[:correct_answers]', data[:num_trues])
    )

    # Chance of reporting incorrect answer is proportional to the size
    # of the event's cash market.  Change in status to "corrupt" does
    # NOT persist across timesteps, or across events.
    if sim.BRIDGE
        data[:corrupt] = falses(data[:num_trues], sim.EVENTS)
        for i = 1:data[:num_trues]
            for j = 1:sim.EVENTS
                if rand() < data[:markets][:size][j] * sim.CORRUPTION
                    data[:corrupt][i,j] = true
                    data[:reports][data[:trues][i],j] = data[:corrupt_answers][j]
                end
            end
        end
    end

    # Distort: report incorrect answers to DISTORT fraction of events
    # (not yet compatible with BRIDGE)
    if sim.DISTORTER
        distmask = rand(data[:num_distorts], sim.EVENTS) .< sim.DISTORT
        correct = convert(
            Matrix{Float64},
            repmat(data[:correct_answers]', data[:num_distorts])
        )
        randomized = convert(
            Matrix{Float64},
            rand(sim.RESPONSES, data[:num_distorts], sim.EVENTS)
        )
        for i = 1:data[:num_distorts]
            for j = 1:sim.EVENTS
                while randomized[i,j] == data[:correct_answers][j]
                    randomized[i,j] = rand(sim.RESPONSES)
                end
            end
        end
        data[:reports][data[:distorts],:] = correct.*~distmask + randomized.*distmask
    end

    # Liar: report answers at random (but with a high chance
    #       of being equal to other liars' answers)
    data[:reports][data[:liars],:] = convert(
        Matrix{Float64},
        rand(sim.RESPONSES, data[:num_liars], sim.EVENTS)
    )
    if sim.SCALARS > 0
        for i = 1:sim.EVENTS
            if data[:scalarmask][i]
                for j = 1:sim.REPORTERS
                    if j in data[:liars]
                        data[:reports][j,i] = rand(data[:scalarmin][i]:data[:stepsize]:data[:scalarmax][i])
                    end
                end
            end
        end
    end

    # "allwrong": liars always answer incorrectly
    # [scalars not supported]
    if sim.ALLWRONG
        @inbounds for i = 1:data[:num_liars]
            for j = 1:sim.EVENTS
                while data[:reports][data[:liars][i],j] == data[:correct_answers][j]
                    data[:reports][data[:liars][i],j] = rand(sim.RESPONSES)
                end
            end
        end
    end

    # All-or-nothing collusion ("conspiracy")
    if sim.CONSPIRACY
        @inbounds for i = 1:data[:num_liars]-1
            diceroll = first(rand(1))
            if diceroll < sim.COLLUDE
                data[:reports][data[:liars][i],:] = data[:reports][data[:liars][1],:]
            end
        end
    end

    # Indiscriminate copying: liars copy anyone, not just other liars
    if sim.INDISCRIMINATE
        @inbounds for i = 1:data[:num_liars]

            # Pairs
            diceroll = first(rand(1))
            if diceroll < sim.COLLUDE
                target = int(ceil(first(rand(1))) * sim.REPORTERS)
                data[:reports][target,:] = data[:reports][data[:liars][i],:]

                # Triples
                if diceroll < sim.COLLUDE^2
                    target2 = int(ceil(first(rand(1))) * sim.REPORTERS)
                    data[:reports][target2,:] = data[:reports][data[:liars][i],:]

                    # Quadruples
                    if diceroll < sim.COLLUDE^3
                        target3 = int(ceil(first(rand(1))) * sim.REPORTERS)
                        data[:reports][target3,:] = data[:reports][data[:liars][i],:]
                    end
                end
            end
        end

    # "Ordinary" (ladder) collusion
    # todo: remove num_liars upper bounds (these decrease collusion probs)
    else
        @inbounds for i = 1:data[:num_liars]-1

            # Pairs
            diceroll = first(rand(1))
            if diceroll < sim.COLLUDE
                data[:reports][data[:liars][i+1],:] = data[:reports][data[:liars][i],:]

                # Triples
                if i + 2 < data[:num_liars]
                    if diceroll < sim.COLLUDE^2
                        data[:reports][data[:liars][i+2],:] = data[:reports][data[:liars][i],:]
        
                        # Quadruples
                        if i + 3 < data[:num_liars]
                            if diceroll < sim.COLLUDE^3
                                data[:reports][data[:liars][i+3],:] = data[:reports][data[:liars][i],:]
                            end
                        end
                    end
                end
            end
        end
    end
    data
end

function generate_data(sim::Simulation, data::Dict{Symbol,Any})
    data[:markets] = populate_markets(sim)
    generate_reports(sim, generate_answers(sim, data))
end

init_reputation(sim::Simulation) = normalize(
    (sim.REP_RAND) ? rand(sim.REP_RANGE, sim.REPORTERS) : ones(sim.REPORTERS)
)
