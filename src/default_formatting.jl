# Provides a default formatter when constructing row specifications
default_fmt(x::Real) = format("{:.3f}", x)
default_fmt(x::Integer) = format(x, commas=true)
default_fmt(x::AbstractString) = x
default_fmt(::Nothing) = ""
default_fmt(x) = string(x)

fmt_coef(x) = (format("{:.3f}", x[1]), format("({:.3f})", x[2]))
fmt_fe(x) = x ? "Yes" : "No"

Row(key, label) = Row(key, string(label), default_fmt)
