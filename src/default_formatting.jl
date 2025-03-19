# Provides a default formatter when constructing row specifications
default_fmt(x::Real) = format("{:.3f}", x)
#default_fmt(x::Real) = string(round(x; digits=4))
default_fmt(x::Integer) = format(x, commas=true)
default_fmt(x::AbstractString) = x
default_fmt(::Nothing) = ""
default_fmt(x) = string(x)

#fmt_coef(x) = (format("{:.3f}", x[1]), format("({:.3f})", x[2]))
fmt_coef(x) = (default_fmt(x[1]), "(" * default_fmt(x[2]) * ")")
fmt_fe(x) = x ? "Yes" : ""

"""
    latex_clean(x)

Escape special characters in LaTeX.
"""
function latex_clean(x)
    special = ['&', '%', '$', '#', '_', '{', '}']
    swaps = [s => "\\$s" for s in special]
    push!(swaps, '~' => raw"\textasciitilde ",
          '^' => raw"\textasciicircum ",
          '\\' => raw"\textbackslash ",
         )
    return replace(x, swaps...)
end
