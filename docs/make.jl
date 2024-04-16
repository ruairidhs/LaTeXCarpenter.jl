using Documenter
using LaTeXCarpenter

makedocs(sitename="LaTeXCarpenter.jl",
         format=Documenter.HTML(assets=["assets/custom.css"]),
         pages = ["Home" => "index.md",
                  "API" => "api.md",
                 ]
        )
