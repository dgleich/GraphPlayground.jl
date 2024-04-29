@testset "PositionForce" begin 
  sim = ForceSimulation(1:10, center=PositionForce())
  for _ in 1:50
    step!(sim)
  end
  @test all( x -> all(xi->abs(xi) <= 0.01, x), sim.positions)
end 