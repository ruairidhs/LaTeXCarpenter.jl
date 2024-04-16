# LaTeXCarpenter.jl

This package creates LaTeX tables from general Julia objects.

It is difficult to balance ease-of-use with flexibility when writing a table-printing package.
This is demonstrated by the existence of several similar packages in the Julia ecosystem, each offering a different level of generality.
I find the level of generality offered by this package useful for a variety of applications, from regression results to less structured statistics.
Please see the documentation for examples of the tables this package can generate.

## Design

The package design is based on data organized by a 2-dimensional index: a source and a tag. Data is presented such that the sources form the table columns and the tags form the table rows. For example, in a regression table, different specifications are the sources and regressors are the tags.
The conceptual difference between a source and a type is that all data of the same type (i.e., rows of the resulting table) is formatted the same way.

For example, the table below lists some statistics about penguins from [PalmerPenguins](https://allisonhorst.github.io/palmerpenguins/articles/intro.html).
Each column (`source`) contains information about a different species of penguin. Rows within a column represent different types of data.
Each row (`type`) contains data of the same type and is formatted the same way, but the values can differ across species.

<img src="docs/src/assets/penguins3.png" width=50% height=50%>

```julia
using LaTeXCarpenter, Format
columns = [Column("Adelie", Dict(:bill_length_mm => 38.824, :body_mass_g => 3713, :islands => ["Torgerson", "Biscoe", "Dream"])),
            Column("Gentoo", Dict(:bill_length_mm => 45.572, :body_mass_g => 5091, :islands => ["Biscoe"])),
            Column("Chinstrap", Dict(:bill_length_mm => 48.832, :body_mass_g => 3634, :islands => ["Dream"])),
           ]
rows = [Row(:bill_length_mm, "Bill length", "{:.2f}mm"),
        Row(:body_mass_g, "Body mass", x -> format("{:.2f}kg", x / 1000)),
        Row(:island, "Islands", identity),
       ]
print_latex_table(rows, columns; midrules=[2])
```

## Alternative packages

There are several other useful packages for generating LaTeX tables from Julia objects.

- [`PrettyTables.jl`](https://github.com/ronisbr/PrettyTables.jl) can print matrices with multiple formatting options and multiple output formats. 
- [`LaTeXTabulars.jl`](https://github.com/tpapp/LaTeXTabulars.jl) makes it easier to write LaTeX `tabular` environment code in Julia.
- [`RegressionTables.jl`](https://github.com/jmboehm/RegressionTables.jl) can print regression results to multiple output formats.
