using GraphPlayground
using Test
using Aqua
using JET

@testset "GraphPlayground.jl" begin
    @testset "Code quality (Aqua.jl)" begin
        Aqua.test_all(GraphPlayground)
    end
    @testset "Code linting (JET.jl)" begin
        JET.test_package(GraphPlayground; target_defined_modules = true)
    end
    # Write your tests here.
end
