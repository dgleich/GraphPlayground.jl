@testset "LinkForce tests" begin
  nodes = [1,2]
  edgelist = [(1, 2)]
  positions = [Point2f(0.0, 0.0), Point2f(10.0, 0.0)]
  sim = ForceSimulation(positions, nodes; 
    link=LinkForce(edges=edgelist, strength=10, distance=1.0, bias=0.5))
  iforce = sim.forces.link
  GraphPlayground.force!(0.1, sim, iforce)  # Assume alpha=0.1

  @test sim.velocities[1][1] > 0  # Node 1 velocity should decrease (move left)
  @test sim.velocities[2][1] < 0  # Node 2 velocity should increase (move right)
  @test sim.velocities[1][2] != 0 # we dont' have zero velocity, because we've jiggled it 
  @test sim.velocities[2][2] != 0
  @test sim.velocities[1][2] <= 10*eps(eltype(sim.velocities[1]))  #  
  @test sim.velocities[2][2] <= 10*eps(eltype(sim.velocities[1]))  #
end  

