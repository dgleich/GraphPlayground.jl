@testset "CenterForce" begin 
  pts = [Point2f(1,1), Point2f(3,3)]
  sim = ForceSimulation(pts, eachindex(pts); center=CenterForce())
  display(sim)
  step!(sim) 
  @test sim.positions[1] ≈ Point2f(-1,-1)
  @test sim.positions[2] ≈ Point2f(1,1)
end 