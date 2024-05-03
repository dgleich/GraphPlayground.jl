
function _count_edges!(counter, edges)
  for e in edges
    src, dst = _srcdst(e)
    counter[src] += 1
    counter[dst] += 1
  end   
end 



"""
LinkForce(edges)
LinkForce(edges; strength=50)
LinkForce(edges; strength=(i,e,src,dst)->val[src]*val[dst], distance=50)
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
  edges = Tuple{Int,Int}[], 
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