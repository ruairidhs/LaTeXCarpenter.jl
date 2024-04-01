# Provides a default formatter when constructing row specifications
default_fmt(x::Real) = format("{:.3f}", x)
default_fmt(x::Integer) = format(x, commas=true)
default_fmt(x::AbstractString) = x
default_fmt(::Nothing) = ""
default_fmt(x) = string(x)

Row(key, label) = Row(key, string(label), default_fmt)
