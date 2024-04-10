"""
    RegressionData

A standardized, light-weight container for regression results and specifications.
"""
struct RegressionData
    coefs::Dict{String, @NamedTuple{coef::Float64, stderror::Float64}}
    fes::Set{Any}
    stats::Dict{Symbol, Any}
end

RegressionData(rr::StatsAPI.RegressionModel) = RegressionData(make_coefficients(rr),
                                                     make_fixed_effects(rr),
                                                     make_stats(rr),
                                                    )

function Base.getindex(D::RegressionData, key::Pair{Symbol, T}) where T
    key_sym, ind = key
    if key_sym == :coef
        return D.coefs[ind]
    elseif key_sym == :fe
        return ind ∈ D.fes
    elseif key_sym == :stat
        return D.stats[ind]
    else
        throw(KeyError(key))
    end
end

function Base.keys(D::RegressionData)
    [[(:coef => k) for k in keys(D.coefs)];
     [(:fe => k) for k in D.fes];
     [(:stat => k) for k in keys(D.stats)]
    ]
end

make_coefficients(rr) = Dict(n => (coef = coef(rr)[idx], stderror = stderror(rr)[idx]) for (idx, n) in enumerate(coefnames(rr)))

function make_fixed_effects(rr)
    fes = Set{Any}()
    if has_fe(rr)
        preds = rr.formula.rhs
        for el in preds
            !has_fe(el) && continue
            push!(fes, extract_fe(el))
        end
    end
    return fes
end
extract_fe(term::StatsModels.FunctionTerm) = term.args[1].sym
extract_fe(term::StatsModels.InteractionTerm) = extract_fe.(term.terms)

r2_within(rr) = rr.r2_within
function make_stats(rr)
    statfuncs = [adjr2, nobs, r2, responsename]
    has_fe(rr) && push!(statfuncs, r2_within)
    Dict(Symbol(f) => f(rr) for f in statfuncs)
end

function label_stat(stat::Symbol)
    labs = Dict(:adjr2 => raw"Adjusted $R^2$",
                :nobs => raw"$N$",
                :r2 => raw"$R^2$",
                :responsename => "Dependent variable",
                :r2_within => raw"Within-$R^2$",
               )
    return labs[stat]
end

## Row generation given a set of regression results
function generate_rows(regs; labels=nothing)
    if isnothing(labels)
        labels = Dict()
    end
    coefs = [Row(:coef => c, apply_label(c, labels), fmt_coef) for c in get_all_coefs(regs)]
    fes = [Row(:fe => fe, apply_label(fe, labels), fmt_fe) for fe in get_all_fes(regs)]
    stats = [Row(:stat => s, label_stat(s), default_fmt) for s in get_all_stats(regs)]
    return (rows = [coefs; 
                    Row(nothing, "\\emph{Fixed effects}"); fes; 
                    Row(nothing, "\\emph{Statistics}"); stats
                   ], midrules = [length(coefs), length(coefs) + length(fes) + 1])
end

get_all_coefs(regs) = unique(mapreduce(coefnames, vcat, regs))
get_all_fes(regs) = unique(mapreduce(make_fixed_effects, union, regs))
function get_all_stats(regs)
    stats = [:nobs, :r2]
    any(has_fe, regs) && push!(stats, :r2_within)
end

apply_label(x::Tuple, labels) = intersperse(apply_label.(x, Ref(labels)), " × ")
function apply_label(x, labels)
    x ∉ keys(labels) && return latex_clean(x)
    return labels[x]
end
latex_clean(s::Symbol) = latex_clean(string(s))
latex_clean(s::AbstractString) = replace(s, "_" => "\\_")

function print_regression_table(io, regs; labels=nothing, kwargs...)
    columns = [Column("($i)", RegressionData(rr)) for (i, rr) in enumerate(regs)]
    rows, midrules = generate_rows(regs; labels=labels)
    print_latex_table(io, rows, columns, midrules=midrules, kwargs...)
end
