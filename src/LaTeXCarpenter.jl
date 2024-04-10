module LaTeXCarpenter

using Format,
      StatsAPI,
      StatsModels,
      FixedEffectModels

export print_latex_table, Column, Row

struct Column{D}
    label::String # used to print
    data::D
end

struct Row{K, F}
    key::K # used to index into the columns
    label::String
    formatter::F
end

include("default_formatting.jl")
include("regression_tables.jl")

"""
    print_latex_table([filepath::AbstractString | String | io::IO], rows, columns; kwargs...)

Return a LaTeX table based on `rows` and `columns`.

The printed result in cell `[row, column]` is the result of indexing into the column data with the row key and applying the row's formatter function.
Each row and column element should be an instance of the respective type.

The output may be written to a file, returned as a string or written to an IO buffer depending on the first argument.

# Formatters

Formatters are functions that transform the data into either a string or a collection of strings, with the later indicating that each element should be printed on a new line in the table string.

# Keyword arguments

- `rowheader::String`: a title for the column containing row labels.
- `transpose::Bool`: transpose the final printed table (i.e., rows are printed as columns).
- `midrules::Vector{Int}`: row indices at which midrules should be placed.
- `title_align::String`: an alignment character for the column titles.
- `multicol_spec::Vector{Tuple{Int, Int, String}}`: specify column groups with syntax `(start column, finish column, group title)`. The row titles are column 0.
- `align_spec::String`: LaTeX tabular alignment, e.g., "lrrrr" for a table with left-aligned row titles and 4 right-aligned columns.
"""
function print_latex_table end

function print_latex_table(::Type{String}, rows, columns;
        rowheader=nothing, transpose=false, midrules = [],
        title_align = "c", multicol_spec = nothing,
        align_spec = make_default_align_spec(columns),
    )
    body = generate_body(rows, columns, rowheader, transpose)
    midrules = expand_midrules(body, midrules)
    body = expand_body(body, title_align)
    composed_body = compose_body(body, midrules, multicol_spec)
    header = generate_header(align_spec)
    footer = generate_footer()
    return compose_table_string(header, composed_body, footer)
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

## Implementation:

## generate and expand the body matrix
function generate_body(rows, columns, rowheader, transpose)
    body = mapreduce(r -> permutedims(generate_body_row(r, columns)), vcat, rows)
    coltitles = map(x -> [x], generate_column_titles(columns, rowheader))
    res = vcat(coltitles, body)
    return transpose ? permutedims(res) : res
end

function generate_body_row(row, columns)
    row_entries = map(columns) do col
        if row.key ∉ keys(col.data)
            return [""]
        else
            formatted = row.formatter(col.data[row.key])
            if !validate_formatted(formatted)
                throw(ArgumentError("Formatting $row and $col resulted in non AbstractString element"))
            end
            if isa(formatted, AbstractString)
                return [formatted]
            else
                return collect(formatted) # transform to vector
            end
        end
    end
    return [[[row.label]]; row_entries]
end

validate_formatted(x::AbstractString) = true #approved
function validate_formatted(x)
    for item in x
        !isa(item, AbstractString) && return false
    end
    return true
end

function generate_column_titles(columns, rowheader)
    mat = Matrix{String}(undef, 1, 1 + length(columns))
    fill!(mat, "")
    if !isnothing(rowheader)
        mat[1, 1] = rowheader
    end
    for (ci, col) in enumerate(columns)
        mat[1, 1 + ci] = col.label
    end
    return mat
end

function expand_midrules(body, midrules)
    rowlengths = map(s -> maximum(length, s), eachslice(body, dims=1))[2:end]
    return map(m -> sum(rowlengths[1:m]), midrules)
end

function expand_body(body, title_align)
    res = mapreduce(expand_row, vcat, eachslice(body, dims=1))
    for col in axes(res, 2)
        res[1, col] = "\\multicolumn{1}{$title_align}{$(res[1, col])}"
    end
    return res
end

function expand_row(row)
    n_elements = maximum(length, row)
    mapreduce(vcat, 1:n_elements) do idx
        permutedims(map(c -> idx <= length(c) ? c[idx] : "", row))
    end
end

## Compose the data into LaTeX code
intersperse(itr, item) = reduce((x, y) -> x * item * y, itr)
combine_row(row) = intersperse(row, " & ") * raw" \\\\"

function compose_body(body_matrix, midrules, multicol_spec)
    midrule_offset = 1 # for the title row
    combined = vec(mapslices(combine_row, body_matrix; dims=2)) # mapslices produces N×1 matrix not vector
    if !isnothing(multicol_spec)
        multicol_header = generate_multicol_header(body_matrix, multicol_spec)
        combined = vcat(multicol_header, combined)
        midrule_offset += 1
    end
    combined[midrule_offset] *= raw"\midrule" # row titles
    for idx in midrules
        combined[idx + midrule_offset] *= raw"\midrule"
    end
    return combined
end

function compose_table_string(components...)
    lines = String[]
    for item in components
        append!(lines, item)
    end
    return intersperse(lines, " \n")
end

make_multicol(start, finish, title) = "\\multicolumn{$(finish-start+1)}{c}{$title}"
make_multicol_line(start, finish, title) = "\\cmidrule(rl){$(start+1)-$(finish+1)} "
function generate_multicol_header(body, spec)
    ncols = size(body, 2)
    header = ""
    spec_loc = 1
    col_loc = 0
    while col_loc <= ncols - 1
        # (a) do we apply the spec?
        if spec_loc <= length(spec) && col_loc == spec[spec_loc][1]
            s = spec[spec_loc]
            header *= make_multicol(s...)
            col_loc = s[2]
            spec_loc += 1
        end
        # (b) are we at the end of the line?
        if col_loc < ncols - 1
            header *= " & "
        else
            header *= raw" \\ "
        end
        col_loc += 1
    end
    # then I need to add the midrules
    for s in spec
        header *= make_multicol_line(s...)
    end
    return header
end

make_default_align_spec(columns) = "l" * repeat("r", length(columns))

function generate_header(alignspec)
    return [raw"\begin{tabular}{" * alignspec * "}",
            raw"\toprule",
           ]
end

function generate_footer()
    return [raw"\bottomrule",
            raw"\end{tabular}",
           ]
end

end#module
