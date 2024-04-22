module GraphPlayground

using GraphMakie
using Random
using Colors
using Makie
using LinearAlgebra
using Graphs
using NearestNeighbors

## import setindex from Base
import Base.setindex

include("utilities.jl")
include("simulation.jl")
export ForceSimulation, step!, fixnode!, freenode!

include("simpleforces.jl")
include("linkforce.jl")
include("manybodyforce.jl")

include("playground.jl")

end
