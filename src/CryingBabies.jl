#=
using POMDPs
using Distributions
using POMDPToolbox
=#

type BabyPOMDP <: POMDP
    r_feed::Float64
    r_hungry::Float64
    p_become_hungry::Float64
    p_cry_when_hungry::Float64
    p_cry_when_not_hungry::Float64
    discount::Float64
end
BabyPOMDP(r_feed, r_hungry) = BabyPOMDP(r_feed, r_hungry, 0.1, 0.8, 0.1, 0.9)

type BabyState
    hungry::Bool
end

type BabyObservation 
    crying::Bool
end

type BabyAction
    feed::Bool
end

type BabyStateDistribution <: Belief
    p_hungry::Float64 # probability of being hungry
end
BabyStateDistribution() = BabyStateDistribution(0.0)

type BabyObservationDistribution <: AbstractDistribution
    p_crying::Float64 # probability of crying
end
BabyObservationDistribution() = BabyObservationDistribution(0.0)


create_state(::BabyPOMDP) = BabyState(false)
create_observation(::BabyPOMDP) = BabyObservation(false)
create_transition_distribution(::BabyPOMDP) = BabyStateDistribution()
create_observation_distribution(::BabyPOMDP) = BabyObservationDistribution()

n_states(::BabyPOMDP) = 2
n_actions(::BabyPOMDP) = 2
n_observations(::BabyPOMDP) = 2

function transition!(d::BabyStateDistribution, pomdp::BabyPOMDP, s::BabyState, a::BabyAction)
    if !a.feed && s.hungry
        d.p_hungry = 1.0
    elseif a.feed 
        d.p_hungry = 0.0
    else
        d.p_hungry = pomdp.p_become_hungry
    end
    d
end


function observation!(d::BabyObservationDistribution, pomdp::BabyPOMDP, s::BabyState, a::BabyAction)
    if s.hungry
        d.p_crying = pomdp.p_cry_when_hungry
    else
        d.p_crying = pomdp.p_cry_when_not_hungry
    end
    d
end

function reward(pomdp::BabyPOMDP, s::BabyState, a::BabyAction)
    r = 0.0
    if s.hungry
        r += pomdp.r_hungry
    end
    if a.feed
        r += pomdp.r_feed
    end
    return r
end

function rand!(rng::AbstractRNG, s::BabyState, d::BabyStateDistribution)
    s.hungry = (rand(rng) <= d.p_hungry)
    return s
end

function rand!(rng::AbstractRNG, o::BabyObservation, d::BabyObservationDistribution)
    o.crying = (rand(rng) <= d.p_crying)
    return o
end

function update_belief!(b::BabyStateDistribution, p::BabyPOMDP, a::BabyAction, o::BabyObservation)
    # bayes rule
    if a.feed
        b.p_hungry = 0.0
    else # did not feed
        b.p_hungry += (1.0-b.p_hungry)*p.p_become_hungry # this is from the system dynamics
        # bayes rule
        if o.crying
            b.p_hungry = (p.p_cry_when_hungry*b.p_hungry)/(p.p_cry_when_hungry*b.p_hungry + p.p_cry_when_not_hungry*(1.0-b.p_hungry))
        else # not crying
            b.p_hungry = ((1.0-p.p_cry_when_hungry)*b.p_hungry)/((1.0-p.p_cry_when_hungry)*b.p_hungry + (1.0-p.p_cry_when_not_hungry)*(1.0-b.p_hungry))
        end
    end
    return b
end

dimensions(::BabyObservationDistribution) = 1
dimensions(::BabyStateDistribution) = 1

function states(::BabyPOMDP)
    [BabyState(i) for i = 0:1]
end

# const ACTION_SET = [BabyAction(i) for i = 0:1]

function actions(::BabyPOMDP)
    return [BabyAction(i) for i in 0:1]
end

function actions!(acts::Vector{BabyAction}, ::BabyPOMDP, s::BabyState)
    acts[1:end] = [BabyAction(i) for i in 0:1] # ACTION_SET[1:end] 
end

# # interpolants don't work for now because I got rid of using Distributions.Bernoulli [This is my (Zach's) fault]
# create_interpolants(::BabyPOMDP) = Interpolants()
# 
# function interpolants!(interpolants::Interpolants, d::BabyStateDistribution)
#     empty!(interpolants)
#     ph = params(d.ishungry)[1]
#     push!(interpolants, 1, (1-ph)) # hungry
#     push!(interpolants, 2, (ph)) # not hungry
#     interpolants
# end
# 
# function interpolants!(interpolants::Interpolants, d::BabyObservationDistribution)
#     empty!(interpolants)
#     ph = params(d.iscrying)[1]
#     push!(interpolants, 1, (1-ph)) # crying
#     push!(interpolants, 2, (ph)) # not crying
#     interpolants
# end
# 
# length(interps::Interpolants) = interps.length
# 
# weight(interps::Interpolants, i::Int64) = interps.weights[i]
# 
# index(interps::Interpolants, i::Int64) = interps.indices[i]

function convert!(x::Vector{Float64}, state::BabyState)
    x[1] = float(state.hungry)
    x
end

discount(p::BabyPOMDP) = p.discount
isterminal(::BabyState) = false