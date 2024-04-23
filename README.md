# GraphPlayground.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://dgleich.github.io/GraphPlayground.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://dgleich.github.io/GraphPlayground.jl/dev/)
[![Build Status](https://github.com/dgleich/GraphPlayground.jl/actions/workflows/CI.yml/badge.svg?branch=main)](https://github.com/dgleich/GraphPlayground.jl/actions/workflows/CI.yml?query=branch%3Amain)
[![Coverage](https://codecov.io/gh/dgleich/GraphPlayground.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/dgleich/GraphPlayground.jl)
[![Aqua](https://raw.githubusercontent.com/JuliaTesting/Aqua.jl/master/badge.svg)](https://github.com/JuliaTesting/Aqua.jl)

This is an extension of [GraphMakie.jl]() that creates an interactive window for graph exploration. 

It includes a port of the [d3-force]() package to Julia to handle the force directed layout. This may be removed at some point. 

Usage
-----
```
using Graphs, GraphPlayground
g = grid([10,10]) # make a 10x10 grid from Graphs
playground(g)
```

This opens an interactive window that will visualize the graph. 