using LaTeXCarpenter
using Test

using DataFrames
using FixedEffectModels
using Statistics

GENERATE = false # generate new regression test data

# Data generation
x = [0.0309, 0.7148, 0.8885, 0.5682, 0.9004, 0.2737, 0.7570, 0.8594, 0.8864, 0.9314]
ϵ = [0.4693, 0.6872, 0.7766, 0.1816, 0.563, 0.3201, 0.207, 0.303, 0.087, 0.8215]
fe1 = [1, 1, 1, 1, 1, 2, 2, 2, 2, 2]
fe2 = [1, 2, 1, 2, 1, 2, 1, 2, 1, 2]
y = @. 0.2 + 3 * x + x ^ 2 + fe1 - 1 + 2 * fe2 + ϵ
df = DataFrame(x = x, x2 = x .^ 2, y = y, state = ifelse.(fe1 .== 1, "NY", "NJ"), year = ifelse.(fe2 .== 1, "2000", "2010"))

# Regression model test
frms = [@formula(y ~ x),
        @formula(y ~ x + x^2),
        @formula(y ~ x + x^2 + fe(state)),
        @formula(y ~ x + x^2 + fe(state) + fe(year)),
       ]
regs = [reg(df, f) for f in frms]
labels = Dict("x" => raw"$x$", "x ^ 2" => raw"$x^2$", :state => "State", :year => "Year", "(Intercept)" => "Constant")

# Dataframes test
stats = combine(groupby(df, :state), [:x, :x2, :y] .=> mean)
columns = [Column(r.state, r) for r in eachrow(stats)]
rows = [Row(:x_mean, raw"$x$"), Row(:x2_mean, raw"$x^2$"), Row(:y_mean, raw"$y$")]

if GENERATE
    print_latex_table("testdata/df_base.tex", rows, columns)
    print_latex_table("testdata/df_transpose.tex", rows, columns; transpose=true)
    print_latex_table("testdata/df_midrules.tex", rows, columns; midrules=[2])
    print_latex_table("testdata/df_multicol.tex", rows, columns; multicol_spec=[(1, 2, "X"), (3, 3, "Y")], transpose=true)
    print_latex_table("testdata/df_rowheader.tex", rows, columns; rowheader = "Mean")
    print_regression_table("testdata/reg_base.tex", regs; labels=labels)
end

@testset "LaTeXCarpenter.jl" verbose=true begin
    @testset "DataFrames.jl" verbose=true begin
        @test print_latex_table(String, rows, columns) == read("testdata/df_base.tex", String)
        @test print_latex_table(String, rows, columns; transpose=true) == read("testdata/df_transpose.tex", String)
        @test print_latex_table(String, rows, columns; midrules=[2]) == read("testdata/df_midrules.tex", String)
        @test print_latex_table(String, rows, columns; multicol_spec=[(1, 2, "X"), (3, 3, "Y")], transpose=true) == read("testdata/df_multicol.tex", String)
        @test print_latex_table(String, rows, columns; rowheader = "Mean") == read("testdata/df_rowheader.tex", String)
    end
    @testset "FixedEffectModels.jl" verbose=true begin
        @test print_regression_table(String, regs; labels=labels) == read("testdata/reg_base.tex", String)
    end
end
