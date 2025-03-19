struct RegressionColumnData{T<:RegressionModel}
    model::T
end

struct CoefKey{T}
    idx::T
end

struct FEKey{T}
    idx::T
end

struct StatKey{T <: Function}
    idx::T
end

struct NullKey end

# Base.haskey
Base.haskey(rr::RegressionColumnData, key::CoefKey) = key.idx ∈ coefnames(rr.model)
function Base.haskey(rr::RegressionColumnData, key::StatKey)
    applicable(key.idx, rr.model)
end
function Base.haskey(rr::RegressionColumnData{T}, key::StatKey) where {T <: StatsModels.TableRegressionModel}
    applicable(key.idx, rr.model.model)
end
Base.haskey(rr::RegressionColumnData, ::FEKey) = true
Base.haskey(rr::RegressionColumnData, ::NullKey) = false

# Base.getindex
function Base.getindex(rr::RegressionColumnData, key::CoefKey)
    loc = findfirst(==(key.idx), coefnames(rr.model))
    isnothing(loc) && throw(KeyError(key))
    return (StatsAPI.coef(rr.model)[loc], StatsAPI.stderror(rr.model)[loc])
end

function Base.getindex(rr::RegressionColumnData, key::StatKey)
    if applicable(key.idx, rr.model)
        return key.idx(rr.model)
    else
        throw(KeyError(key))
    end
end

function Base.getindex(rr::RegressionColumnData{T}, key::StatKey) where {T <: StatsModels.TableRegressionModel}
    if applicable(key.idx, rr.model.model)
        return key.idx(rr.model.model)
    else
        throw(KeyError(key))
    end
end

# fixed effects
get_fes(::RegressionModel) = Any[]
Base.getindex(rr::RegressionColumnData, key::FEKey) = key.idx ∈ get_fes(rr.model)

##
function apply_labels(labels, row)
    if haskey(labels, row)
        return labels[row]
    else
        return latex_clean(string(row))
    end
end

function apply_labels(labels, row::Tuple)
    return intersperse(apply_labels.(Ref(labels), row), " × ")
end

get_all_coefnames(regs) = mapreduce(coefnames, union, regs)
function get_coefficient_rows(coefs, labels)
    return [Row(CoefKey(c), apply_labels(labels, c), fmt_coef) for c in coefs]
end

function get_stats_rows(stats, labels)
    return [Row(NullKey(), raw"\emph{Statistics}");
            [Row(StatKey(s), apply_labels(labels, s)) for s in stats]
           ]
end

function get_fe_rows(fes, labels)
    return [Row(NullKey(), raw"\emph{Fixed Effects}");
            [Row(FEKey(fe), apply_labels(labels, fe), fmt_fe) for fe in fes]
           ]
end

## Building the table
default_stats() = [StatsAPI.nobs, StatsAPI.r2]
default_colnames(regs) = ["($i)" for i in eachindex(regs)]
function add_stats_labels(labels)
    default_stat_labels = Dict{Any, String}(StatsAPI.nobs => raw"$N$", StatsAPI.r2 => raw"$R^2$")
    if isempty(labels)
        return default_stat_labels
    else
        # user choice will override
        return push!(default_stat_labels, labels...)
    end
end

"""
    get_regression_table_format(regs; reg_kwargs...)

Makes the row and column specifications for a regression table but does not construct the final table.

The resulting rows and columns can be passed to [`print_latex_table`](@ref).
See [`print_regression_table`](@ref) for keyword arguments.
"""
function get_regression_table_format(regs; 
        labels = Dict(),
        coefs=get_all_coefnames(regs), 
        stats=default_stats(), 
        fes = mapreduce(get_fes, union, regs),
        colnames=default_colnames(regs), 
    )
    labels = add_stats_labels(labels)

    coef_rows = get_coefficient_rows(coefs, labels)
    stat_rows = get_stats_rows(stats, labels)
    if !isempty(fes)
        fe_rows = get_fe_rows(fes, labels)
        rows = [coef_rows; fe_rows; stat_rows]
        midrules = [length(coef_rows), sum(length, (coef_rows, fe_rows))]
    else
        rows = [coef_rows; stat_rows]
        midrules = [length(coef_rows)]
    end

    columns = [Column(n, RegressionColumnData(r)) for (n, r) in zip(colnames, regs)]

    return (rows=rows,
        columns=columns,
        midrules=midrules
    )
end

"""
    print_regression_table([filepath::AbstractString | String | io::IO], regs::Vector{RegressionModel}; reg_kwargs..., table_kwargs...)

Print a regression table based on with columns determined by `regs`.

# Keyword arguments

All keyword arguments for [`print_latex_table`](@ref) are also available.
Additional keyword arguments for regression tables are:

- `labels::Dict`: used to rename regression coefficients, fixed effects and statistics. For example, if "x1" is a regression coefficient, `"x1" => raw"\$x_{1}\$"` may be an element of `labels`. Fixed effects should be indexed by a `Symbol`, e.g., `:state => "State"`.
- `coefs`: a vector of coefficient names to include in the table. Defaults to all coefficients included in any of `regs`. Can also be used to change the order of coefficients in the table.
- `stats=[nobs, r2]`: a vector of statistics to include in the regression.
- `fes`: a vector of fixed effects to include in the table. Defaults to all fixed effects included in any of `regs`.
- `colnames=["(1)", "(2)", ...]`: a vector of column names.
"""
function print_regression_table(io, regs;
        labels = Dict(),
        coefs=get_all_coefnames(regs), 
        stats=default_stats(), 
        fes = mapreduce(get_fes, union, regs),
        colnames=default_colnames(regs), 
        kwargs...
    )
    (; rows, columns, midrules) = get_regression_table_format(regs; labels=labels, coefs=coefs, stats=stats, fes=fes, colnames=colnames)
    print_latex_table(io, rows, columns; midrules=midrules, kwargs...)
end

print_regression_table(regs; kwargs...) = print_regression_table(stdout, regs; kwargs...)
