"""
ManyBodyForce()
ManyBodyForce(strength=-50)
ManyBodyForce(edges; strength=(src,dst)->val[src]*val[dst], distance, rng)

- strength - the repulsive strength to use, defaults to -30
- rng - the random number generator to jiggle close points 
- min_distance2 - where to lower-bound force application 
- max_distance2 - where to cutoff force application 
- theta2 - where to apply the quadtree approximation 
"""
struct ManyBodyForce{T}
  args::T 
end 
ManyBodyForce(;kwargs...) = ManyBodyForce{typeof(kwargs)}(kwargs)
export ManyBodyForce

struct InitializedManyBodyForce
  strengths
  min_distance2
  max_distance2
  theta2
  rng
end

function initialize(link::ManyBodyForce, nodes; 
  strength = -30.0, 
  min_distance2 = 1.0,
  max_distance2 = Inf,
  theta2 = 0.81,
  random = nothing)

  strength = _handle_node_values(nodes, strength)

  return InitializedManyBodyForce(strength, min_distance2, max_distance2, theta2, random)
end

function manybodyforce!(alpha::Real, nodes, pos, vel, strengths, min_distance2, max_distance2, theta2, rng)
  for u in eachindex(nodes)
    for v in eachindex(nodes)
      if u == v
        continue
      end
      d = pos[v] .- pos[u]
      d2 = dot(d, d)
      if d2 < max_distance2
        d = jiggle(d, rng)
        d2 = dot(d, d)
        if d2 < min_distance2
          d2 = sqrt(min_distance2*d2)
        end

        w = strengths[v]*alpha / d2
        vel[u] += d .* w 
      end
    end
  end
end

function force!(alpha::Real, sim::ForceSimulation, many::InitializedManyBodyForce)
  pos = sim.positions
  vel = sim.velocities
  nodes = sim.nodes
  strengths = many.strengths
  min_distance2 = many.min_distance2
  max_distance2 = many.max_distance2
  theta2 = many.theta2
  rng = many.rng 

  manybodyforce!(alpha, nodes, pos, vel, strengths, min_distance2, max_distance2, theta2, rng)
end

function Base.show(io::IO, z::InitializedManyBodyForce)
  print(io, "ManyBodyForce")
end 
