using GraphPlayground
using Test
using Aqua
using JET
using StableRNGs
using GeometryBasics



@testset "GraphPlayground.jl" begin

  include("linkforce.jl")
  include("manybodyforce.jl")
  include("positionforce.jl")

  @testset "Code quality (Aqua.jl)" begin
    Aqua.test_all(GraphPlayground;
      ambiguities = false
    )
  end
  @testset "Code linting (JET.jl)" begin
    JET.test_package(GraphPlayground; target_defined_modules = true)
  end  

end
