function _one_vertex(g)
  return first(vertices(g))
end 

function _diameter_estimate(g)
  nsamp = 2*ceil(Int, log2(ne(g)))
  vs = vertices(g)
  random_vertices = rand(vs, nsamp)
  return maximum(
    v -> 2*eccentricity(g, v), 
    random_vertices
  )
end 

function default_force_simulation(g)
  conn = _is_connected(g)
  diam_est = _diameter_estimate(g) 
  link_iterations = 1 
  if diam_est >= ne(g)^(1/3)
    # this is a big diameter.. we need to do more iterations
    link_iterations = 10
  end 
  if ne(g) <= 50
    # this is a small graph, we can afford to space things out more

  end 

  

  return ForceSimulation(
    g, 
    vertices(g), 
    link=LinkForce(;iterations=link_iterations),
    position=PositionForce(;strength=0.01),
    center=CenterForce(;strength=0.01),
    charge=ManyBodyForce(;strength=conn ? -1.0 : -0.5),
    alpha=GraphPlayground.CoolingStepper(alpha_target=0.3),
    velocity_decay=0.9
  )

end 