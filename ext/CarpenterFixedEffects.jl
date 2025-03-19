module CarpenterFixedEffects

using LaTeXCarpenter
using FixedEffectModels

get_fe(t::FunctionTerm{typeof(fe)}) = t.args[1].sym
get_fe(::FunctionTerm) = nothing
get_fe(t::InteractionTerm) = map(get_fe, t.terms)
get_fe(::Term) = nothing
LaTeXCarpenter.get_fes(rr::FixedEffectModel) = filter(!isnothing, get_fe.(rr.formula.rhs))

end#extension
