function compute_metrics(sim::Simulation,
                         data::Dict{Symbol,Any},
                         outcomes::Vector{Float64},
                         initial_rep::Vector{Float64},
                         updated_rep::Vector{Float64})

    # Changes in reputation this round
    rep_change = updated_rep - initial_rep

    consensus = updated_rep' * data[:reports]
    consensus = squeeze(consensus', 2)
    data[:num_answers_correct] = zeros(sim.REPORTERS)
    for r = 1:sim.REPORTERS
        data[:num_answers_correct][r] = sum(squeeze(data[:reports][r,:]', 2) .== data[:correct_answers])
    end

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

    # Histogram reputation
    if sim.HISTOGRAM
        repcount = reputation_distribution(sim, updated_rep)
    end

    # Gini coefficient
    gini = sum([i*r for (i,r) in enumerate(sort(updated_rep))]) / sum(updated_rep)
    gini *= 2 / sim.REPORTERS
    gini -= 1 + 1 / sim.REPORTERS

    true_rep = sum(updated_rep[data[:trues]])
    liar_rep = sum(updated_rep[data[:liars]])

    metrics = (Symbol => Float64)[
        # Spearman's rank correlation coefficient
        :spearman => corspearman(data[:num_answers_correct], updated_rep), 

        # Sensitivity (recall/true positive rate): liars punished / num liars
        :sensitivity => liars_punished / data[:num_liars],

        # Precision (positive predictive value): liars punished / total punished
        :precision => liars_punished / total_punished,

        # Fall-out/false positive rate (1 - specificity):
        # 1 - trues rewarded / num trues
        :fallout => 1.0 - sum(~tested_as_liars[data[:trues]]) / data[:num_trues],

        # "liars_bonus": total bonus reward liars received (in excess of
        #                true reporters') relative to total reputation
        :liars_bonus => sum(bonus[data[:liars]]),

        # "beats" are liars that escaped punishment (i.e, false negatives)
        :beats => sum(bonus[data[:liars]] .>= 0) / data[:num_liars],

        # Outcomes that matched our known correct answers list
        :correct => countnz(outcomes .== data[:correct_answers]) / sim.EVENTS,

        # :repcount => repcount,
        :gini => gini,
        :true_rep => true_rep,
        :liar_rep => liar_rep,
        :gap => true_rep - liar_rep,
    ]
    if sim.DISTORTER
        metrics[:distorts_bonus] = sum(bonus[data[:distorts]])
        metrics[:distorts_rep] = sum(updated_rep[data[:distorts]])
    else
        # Matthews correlation coefficient
        if total_punished == 0 || data[:num_liars] == 0 || data[:num_trues] == 0 || total_rewarded == 0
            metrics[:MCC] = 0
        else
            metrics[:MCC] = liars_punished*trues_rewarded - liars_rewarded*trues_punished
            metrics[:MCC] /= sqrt(total_punished*data[:num_liars]*data[:num_trues]*total_rewarded)
        end
    end
    if sim.BRIDGE
        metrics[:corrupted] = countnz(data[:corrupt]) / data[:num_trues] / sim.EVENTS
    end
    metrics
end

# Reputation distribution (key=bin center, value=count)
function reputation_distribution(sim::Simulation, updated_rep::Vector{Float64})
    bins = linspace(0, 1, sim.REP_BINS)
    repcount = [i::Float64 => 0 for i in bins]
    for r in updated_rep
        repcount[bins[indmin(abs(bins - r))]] += 1
    end
    repcount
end
