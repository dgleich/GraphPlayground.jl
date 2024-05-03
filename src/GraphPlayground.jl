module GraphPlayground

using GraphMakie
using Random
using Colors
using Makie
using LinearAlgebra
using Graphs
using NearestNeighbors

## import setindex from Base
import Base.setindex, Base.eltype, Base.zero, Base.show 

include("utilities.jl")
include("simulation.jl")
export ForceSimulation, step!, fixnode!, freenode!

include("simpleforces.jl")
export CenterForce, PositionForce
include("linkforce.jl")
export LinkForce
include("manybodyforce.jl")
export ManyBodyForce

include("playground.jl")
export playground

end
