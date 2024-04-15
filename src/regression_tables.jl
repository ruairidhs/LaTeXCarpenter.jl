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

get_fes(::RegressionModel) = Any[]

Base.getindex(rr::RegressionColumnData, key::FEKey) = false

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
