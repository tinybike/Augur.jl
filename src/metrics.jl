function compute_metrics(sim::Simulation,
                         data::Dict{Symbol,Any},
                         outcomes::Vector{Any},
                         initial_rep::Vector{Float64},
                         updated_rep::Vector{Float64})

    # Changes in reputation this round
    rep_change = updated_rep - initial_rep

    # Difference between reputation received and that received by honest reporters
    bonus = rep_change - rep_change[first(data[:trues])]

    # Reporters test as liars if they have less reputation now than they did
    # at the start of the round
    tested_as_liars = updated_rep .< initial_rep

    # Confusion matrix: lie detection as a binary classifier
    liars_punished = sum(tested_as_liars[data[:liars]])  # true positive
    trues_punished = sum(tested_as_liars[data[:trues]])  # false positive
    liars_rewarded = sum(~tested_as_liars[data[:liars]]) # false negative
    trues_rewarded = sum(~tested_as_liars[data[:trues]]) # true negative
    total_punished = liars_punished + trues_punished
    total_rewarded = trues_rewarded + liars_rewarded

    # Sensitivity (recall/true positive rate): liars punished / num liars
    sensitivity = liars_punished / data[:num_liars]

    # Precision (positive predictive value): liars punished / total punished
    precision = liars_punished / total_punished

    # Matthews correlation coefficient
    MCC = liars_punished*trues_rewarded - liars_rewarded*trues_punished
    MCC /= sqrt(total_punished*data[:num_liars]*data[:num_trues]*total_rewarded)

    # Reputation distribution (key=bin center, value=count)
    # bins = linspace(0, 1, sim.REP_BINS)
    # repcount = [i::Float64 => 0 for i in bins]
    # for r in updated_rep
    #     repcount[bins[indmin(abs(bins - r))]] += 1
    # end

    # Gini coefficient
    gini = sum([i*r for (i,r) in enumerate(sort(updated_rep))]) / sum(updated_rep)
    gini *= 2 / sim.REPORTERS
    gini -= 1 + 1 / sim.REPORTERS

    true_rep = median(updated_rep[data[:trues]])
    liar_rep = median(updated_rep[data[:liars]])

    # (Symbol => Union(Float64, Dict{Float64,Int}))[
    (Symbol => Float64)[
        :sensitivity => sensitivity,
        :precision => precision,

        # Fall-out/false positive rate (1 - specificity): 1 - trues rewarded / num trues
        :fallout => 1.0 - sum(~tested_as_liars[data[:trues]]) / data[:num_trues],

        # "liars_bonus": total bonus reward liars received (in excess of
        #                true reporters') relative to total reputation
        :liars_bonus => sum(bonus[data[:liars]]),
        :distorts_bonus => sum(bonus[data[:distorts]]),

        # "beats" are liars that escaped punishment (i.e, false negatives)
        :beats => sum(bonus[data[:liars]] .>= 0) / data[:num_liars],

        # Outcomes that matched our known correct answers list
        :correct => countnz(outcomes .== data[:correct_answers]) / sim.EVENTS,

        # :repcount => repcount,
        :MCC => MCC,
        :gini => gini,
        :true_rep => true_rep,
        :liar_rep => liar_rep,
        :gap => true_rep - liar_rep,
    ]
end
