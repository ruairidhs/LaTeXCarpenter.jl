module LaTeXTables

using Printf

export print_latex_table, TableColumn, ColumnGroup

"""
    TableColumn(name::String, data)

Contains a column name and data for the LaTeX table.

The type of `data` must implement `getindex` and `keys`.
"""
struct TableColumn{D}
    name::String
    data::D
end
TableColumn(n::AbstractString, d) = TableColumn(String(n), d)

struct ColumnGroup{D}
    name::String
    cols::D
end
ColumnGroup(n::AbstractString, d) = ColumnGroup(String(n), d)
Base.length(group::ColumnGroup) = length(group.cols)

struct Labeller{T}
    labels::T
end
function Base.getindex(labels::Labeller, key)
    key ∉ keys(labels.labels) && return string(key)
    return labels.labels[key]
end

"""
    print_latex_table([filepath::AbstractString | String | io::IO], rows, columns; kwargs...)

Return a LaTeX table based on `rows` and `columns`.

The output may be written to a file, returned as a string or written to an IO buffer depending on the first argument.

# Arguments

- `rows` is an ordered specification of row specs. A row spec is either just the row name or a tuple of the label and a formatter. The data in cell [row, column] is retrieved by indexing into the column using the row name. If the row name is not in the column then an empty cell is printed.
- `columns` is an ordered collection with element type `TableColumn`.

# Formatters

Formatters are functions that may be optionally included in a row spec. A formatter should return either a single string or a collection of strings, with the later indicating that each element should be printed on a new line in the table cell.

# Optional arguments
# - `labels`: a dictionary used to rename row and columns in the final output.
# - `midrules`=[1]: a vector of row indices before which to place a "\\midrule"
# - `default_formatter`: a formatter to use whenever one is not included in a row spec.
"""
function print_latex_table end

function print_latex_table(::Type{String}, rows, columns; kwargs...)
    row_strings = build_table(rows, columns; kwargs...)
    return reduce(*, intersperse(row_strings, "\n"))
end

function print_latex_table(io::IO, rows, columns; kwargs...)
    s = print_latex_table(String, rows, columns; kwargs...)
    write(io, s)
    return nothing
end

function print_latex_table(file::AbstractString, rows, columns; kwargs...)
    s = print_latex_table(String, rows, columns; kwargs...)
    write(file, s)
    return nothing
end

## Default formatting
fmt(x::Real) = @sprintf "%.3f" x
fmt(x::Integer) = @sprintf "%i" x
fmt(x::AbstractString) = x
fmt(::Nothing) = ""
parens(s) = "(" * s * ")"

expand_row(rspec::Tuple, formatter) = rspec
expand_row(rspec, formatter) = (rspec, formatter)
expand_rows(rows, formatter) = map(r -> expand_row(r, formatter), rows)

## Building the rowmap which assigns row labels to row indices
count_rows(::String) = 1
count_rows(x) = length(x)
function count_rowspec(rspec, columns)
    rname, formatter = rspec
    nrows = 0
    for column in columns
        rname ∉ keys(column.data) && continue
        output_length = count_rows(formatter(column.data[rname]))
        if nrows == 0 # this is the first one we found
            nrows = output_length
        else # we already found something else
            nrows != output_length && throw(ArgumentError("$rname formatter returns multiple length outputs"))
        end
    end
    # if this row is not found in any columns, still print a blank row, so return 1 not 0
    return nrows == 0 ? 1 : nrows
end

function make_rowmap(rows, columns)
    pairs, nrows = reduce(rows; init=([], 0)) do (stack, idx), rspec
        rname, formatter = rspec
        nrows = count_rowspec(rspec, columns)
        final = idx + nrows
        push!(stack, rname => (idx+1:final, formatter))
        return stack, final
    end
    return Dict(pairs...), nrows
end

## Constructing the table
function make_column(col, rowmap, nrows)
    # Formats and orders the data in a column
    result = Vector{String}(undef, nrows)
    fill!(result, "") # default is blank
    for (rowname, (idx, formatter)) in rowmap
        rowname ∉ keys(col.data) && continue
        result[idx] .= formatter(col.data[rowname])
    end
    return result
end

make_body(columns, rowmap, nrows) =
    mapreduce(hcat, columns) do column
        make_column(column, rowmap, nrows)
    end

function make_column_titles(columns, labels, columns_name)
    result = [isnothing(columns_name) ? "" : columns_name; ["\\multicolumn{1}{c}{" * labels[col.name] * "}" for col in columns]]
    return permutedims(result)
end

function make_row_titles(rows, rowmap, nrows, labels)
    result = Vector{String}(undef, nrows)
    fill!(result, "") # default is blank
    for (name, _) in rows
        indices, _ = rowmap[name]
        result[first(indices)] = labels[name]
    end
    return result
end

function reduce_row(row)
    with_ampersand = reduce(*, intersperse(row, " & "))
    return with_ampersand * " \\\\"
end

make_tabular_spec(columns) = "\\begin{tabular}{l" * repeat("r", length(columns)) * "}"

function build_mainbody(rows, columns, labels, midrules, columns_name)
    rowmap, nrows = make_rowmap(rows, columns)
    # make the table
    table = make_body(columns, rowmap, nrows)
    table = hcat(make_row_titles(rows, rowmap, nrows, labels), table)
    table = vcat(make_column_titles(columns, labels, columns_name), table)
    table = map(reduce_row, eachslice(table, dims=1))
    add_midrules!(table, rowmap, midrules)
    return table
end

function add_midrules!(table, rowmap, midrules)
    # each midrule means: place before this idx
    indices = sort([rng for (rowname, (rng, fmt)) in rowmap], by=first)
    for (n, pos) in enumerate(midrules)
        base = first(indices[pos])
        insert!(table, base + n, "\\midrule")
    end
    return table
end

function build_table(rows, columns; labels=Dict(), midrules=[1], default_formatter=fmt, columns_name = nothing)
    labels = Labeller(labels)
    rows = expand_rows(rows, default_formatter) # add the default
    if eltype(columns) <: ColumnGroup
        base_columns = vcat((g.cols for g in columns)...)
        header = append!([make_tabular_spec(base_columns), "\\toprule"], make_groups_rows(columns, labels))
    else
        base_columns = columns
        header = [make_tabular_spec(base_columns), "\\toprule"]
    end
    table = build_mainbody(rows, base_columns, labels, midrules, columns_name)
    result = [header;
        table;
        ["\\bottomrule", "\\end{tabular}"]
    ]
    return result
end

## Grouped columns
function make_groups_rows(groups, labels)
    header_multicolumn(group) = "\\multicolumn{$(length(group))}{c}{$(labels[group.name])}"
    group_row = "& " * reduce(*, intersperse(map(header_multicolumn, groups), " & ")) * " \\\\"
    line_row, _ = foldl(groups; init = ("", 2)) do (row, idx), group
        target = idx + length(group) - 1
        mr = " \\cmidrule(lr){$idx-$target}"
        return row * mr, target + 1
    end
    return [group_row, line_row]
end

## Utilities
function intersperse(collection, item)
    head, tail = Iterators.peel(collection)
    prepended = Iterators.flatten(zip(Iterators.repeated(item), tail))
    return [head; collect(prepended)]
end

end#module
