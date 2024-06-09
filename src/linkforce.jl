function _count_edges!(counter, edges)
  for e in edges
    src, dst = _srcdst(e)
    counter[src] += 1
    counter[dst] += 1
  end   
end 

"""
    LinkForce(;edges)
    LinkForce(;edges, [strength], [distance], [bias], [iterations], [random])

A link force computes forces between nodes that emulate a strong connection. 
This is useful for graphs where the edges represent strong connections between nodes.

The force applied between two nodes is based on the strength of the link, the distance,
the strength of the edge. The bias of the edge is used to determine how much the nodes
should move.

For an edge between `src`, `dst`, let ``d`` be the difference vector 
between the position of `dst` and `src` _with their velocity corrections included_.
The total force is ``f = \\alpha \\cdot s \\cdot (||d|| - l) / ||d||`` where ``l`` is the ideal distance
and ``s`` is the strength of the link. The force is applied to the velocity of the nodes
proportional to the bias of the edge ``\\beta``

      `vel[dst] -=` ``\\beta f \\cdot d``
      `vel[src] +=` ``(1-\\beta) f \\cdot d``

The bias is used to determine how much the nodes should move. If the bias is 0, then the 
update is exclusively provided to the `src` node. If the bias is 1, then the update is 
exclusively provided to the `dst` node.

## Arguments
- `edges`: An array of edge structures, where each edge structure contains `src` and `dst` fields
  or can be indexed like a tuple with e[1], e[2] as the source and destination nodes. 

## Optional Arguments
- `strength`: A function or array of values that determine the strength of the link between two nodes.
  By default, this is based on the number of edges between the nodes: 1/(min(degree(src), degree(dst))).
- `distance`: A function or array of values that determine the ideal distance between two nodes.
  By default, this is 30.0.  But this can be a function that takes the edge index and returns a distance.
- `bias`: A function or array of values that determine the bias of the link between two nodes.
  This is designed to weight how much the nodes should move. It's designed to make it harder to
  move high degree nodes. 
- `iterations`: The number of iterations to run the link force. The default is 1.
  Each iteration updates the velocity but not the positions. However, the velocity updates
  are included in the force calculations. So by running multiple iterations, the forces
  are more accurate. This is because we update the velocities in-place. 
  Using large values here are most important for grids or graphs with a lot of structure.   
- `random`: A random number generator. This is used for the random perturbations. 
  The default is to use a deterministic generator so that the results are reproducible.
  I can't imagine why you would need to use this, but it's here in case someone needs
  to reproduce something strange. 

## Function inputs
An exmaple of using it with a function is the following
```julia
val = randn(10)
f = LinkForce(;edges=edges, strength=(i,e,src,dst)->val[src]*val[dst])
```
This is called with 
- `i`: The index of the edge in the edges array.
- `e`: The edge structure.
- `src`: The source node.
- `dst`: The destination node.
This same structure is used for all strength, bias, and distance. 

## Usage
LinkForce is usually used as part of a ForceSimulation.
Here, we setup something simple with two nodes at distance 1.
But that want to be at distance 10 given the edge between them. 
```julia
nodes = [1,2]
edgelist = [(1, 2)]
positions = [Point2f(0.0, 0.0), Point2f(1.0, 0.0)]
sim = ForceSimulation(positions, nodes; 
  link=LinkForce(edges=edgelist, strength=10, distance=10.0, bias=0.25))
iforce = sim.forces.link
# iforce is an `InitializedLinkForce` that's been linked to the simulation
GraphPlayground.force!(0.1, sim, iforce)  # Assume alpha=0.1
sim.velocities
```
This example shows how the [`LinkForce`]computes the velocities of the nodes
to move them away from each other. The reason the update is nonsymmetric
is because of the bias. This says that we want to move node 1 more than node 2.

## See also 
[`ForceSimulation`](@ref)
"""
struct LinkForce{T}
  args::T 
end 
#LinkForce(edges) = LinkForce(edges=edges)
LinkForce(;kwargs...) = LinkForce{typeof(kwargs)}(kwargs)

struct InitializedLinkForce
  edges
  biases
  strengths
  distances
  rng
  iterations::Int
end

function Base.show(io::IO, z::InitializedLinkForce)
  print(io, length(z.edges), "-edge LinkForce")
end 

function initialize(link::LinkForce, nodes; 
  edges, 
  strength = nothing, 
  distance = 30.0,
  bias = nothing, 
  iterations = 1,
  random = nothing)

  if strength === nothing || bias === nothing 
    # count degrees to initialize srength and bias
    count = _get_node_array(Int, nodes) 
    fill!(count, 0)
    _count_edges!(count, edges)

    if strength === nothing 
      strength = _handle_link_values(edges, (i,e,src,dst) -> 1.0 / min(count[src], count[dst]))
    else
      strength = _handle_link_values(edges, strength)
    end

    if bias === nothing 
      bias = _handle_link_values(edges, (i,e,src,dst) -> count[src] / (count[src] + count[dst]))
    else 
      bias = _handle_link_values(edges, bias)
    end
  else
    strength = _handle_link_values(edges, strength)
    bias = _handle_link_values(edges, bias)
  end

  distance = _handle_link_values(edges, distance)

  return InitializedLinkForce(edges, bias, strength, distance, random, iterations)
end

function initialize(link::LinkForce, sim::ForceSimulation)
  return initialize(link, sim; link.args...)
end

function linkforce!(alpha::Real, pos, vel, edges, biases, strengths, distances, rng, niter)
  for k in 1:niter
    for (i,e) in enumerate(edges)
      src, dst = _srcdst(e) 
      #= 
      link = links[i], source = link.source, target = link.target;
        x = target.x + target.vx - source.x - source.vx || jiggle(random);
        y = target.y + target.vy - source.y - source.vy || jiggle(random);
        l = Math.sqrt(x * x + y * y);
        l = (l - distances[i]) / l * alpha * strengths[i];
        x *= l, y *= l;
        target.vx -= x * (b = bias[i]);
        target.vy -= y * b;
        source.vx += x * (b = 1 - b);
        source.vy += y * b;
      =#
      diff = pos[dst] .+ vel[dst] .- pos[src] .- vel[src]
      diff = jiggle(diff, rng)
      l = norm(diff) 
      l = (l - distances[i]) / l * alpha * strengths[i]
      diff *= l
      vel[dst] -= diff .* biases[i]
      vel[src] += diff .* (1 - biases[i])
    end 
  end 
end

function force!(alpha::Real, sim::ForceSimulation, link::InitializedLinkForce)
  iters = link.iterations
  pos = sim.positions
  vel = sim.velocities
  bias = link.biases
  strengths = link.strengths
  distances = link.distances  
  edges = link.edges
  rng = link.rng 

  linkforce!(alpha, pos, vel, edges, bias, strengths, distances, rng, iters)
end