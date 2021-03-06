using FastAlgebraicDataTypes
using Documenter

DocMeta.setdocmeta!(FastAlgebraicDataTypes, :DocTestSetup, :(using FastAlgebraicDataTypes); recursive=true)

makedocs(;
    modules=[FastAlgebraicDataTypes],
    authors="Jan Weidner <jw3126@gmail.com> and contributors",
    repo="https://github.com/jw3126/FastAlgebraicDataTypes.jl/blob/{commit}{path}#{line}",
    sitename="FastAlgebraicDataTypes.jl",
    format=Documenter.HTML(;
        prettyurls=get(ENV, "CI", "false") == "true",
        canonical="https://jw3126.github.io/FastAlgebraicDataTypes.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/jw3126/FastAlgebraicDataTypes.jl",
    devbranch="main",
)
