function create_reporters(sim::Simulation)
    if sim.DISTORTER
        distort_threshold = sim.LIAR_THRESHOLD + sim.DISTORT_THRESHOLD
        distort_threshold <= 1.0 || throw(BoundsError())
    else
        distort_threshold = sim.LIAR_THRESHOLD
    end

    # 1. Generate artificial "true, distort, liar" list
    honesty = rand(sim.REPORTERS)
    reporters = fill("", sim.REPORTERS)
    reporters[honesty .>= distort_threshold] = "true"
    reporters[sim.LIAR_THRESHOLD .< honesty .< distort_threshold] = "distort"
    reporters[honesty .<= sim.LIAR_THRESHOLD] = "liar"

    # 2. Build report matrix from this list
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

function generate_data(sim::Simulation, data::Dict{Symbol,Any})
    data[:correct_answers] = rand(sim.RESPONSES, sim.EVENTS)

    # True: always report correct answer
    data[:reports] = zeros(sim.REPORTERS, sim.EVENTS)
    data[:reports][data[:trues],:] = convert(
        Matrix{Float64},
        repmat(data[:correct_answers]', data[:num_trues])
    )

    # Distort: report incorrect answers to DISTORT fraction of events
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

    # Liar: report answers at random (but with a high chance
    #       of being equal to other liars' answers)
    data[:reports][data[:liars],:] = convert(
        Matrix{Float64},
        rand(sim.RESPONSES, data[:num_liars], sim.EVENTS)
    )

    # "allwrong": liars always answer incorrectly
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
    ~sim.VERBOSE || display([data[:reporters] data[:reports]])
    data
end
