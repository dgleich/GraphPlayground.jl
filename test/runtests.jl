using GraphPlayground
using Test
using Aqua
using JET
using StableRNGs
using GeometryBasics
using Graphs

##
#=@testset "dev" begin
  using NearestNeighbors
  # create a set of points that are on x axis from 0 to 1
  n = 100 
  pts = [Point2f(i, 0) for i in range(start=1.0, stop=0.01, length=n)]
  radii = range(start=1.0, stop=0.01, length=100)
  p = randperm(StableRNG(0), 100)
  pts = pts[p]
  radii = radii[p]
  T = KDTree(pts)
  maxradius = GraphPlayground._build_tree_info_maxradius(T, pts, radii)
end=#

##
@testset "GraphPlayground.jl" begin
  include("linkforce.jl")
  include("manybodyforce.jl")
  include("positionforce.jl")
  include("centerforce.jl")
  include("d3-compare.jl")

  include("examples.jl")

  println("Starting Aqua and JET tests...")

  @testset "Code quality (Aqua.jl)" begin
    Aqua.test_all(GraphPlayground;
      ambiguities = false
    )
  end
  @testset "Code linting (JET.jl)" begin
    JET.test_package(GraphPlayground; target_defined_modules = true)
  end  
end
