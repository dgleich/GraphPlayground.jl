using GraphPlayground
using Documenter

DocMeta.setdocmeta!(GraphPlayground, :DocTestSetup, :(using GraphPlayground); recursive=true)

makedocs(;
    modules=[GraphPlayground],
    authors="David Gleich <dgleich@purdue.edu> and contributors",
    sitename="GraphPlayground.jl",
    format=Documenter.HTML(;
        canonical="https://dgleich.github.io/GraphPlayground.jl",
        edit_link="main",
        assets=String[],
    ),
    pages=[
        "Home" => "index.md",
    ],
)

deploydocs(;
    repo="github.com/dgleich/GraphPlayground.jl",
    devbranch="main",
)
