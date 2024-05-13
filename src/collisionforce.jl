"""
    CollisionForce([radius, strength])
    
"""

struct CollisionForce{T}
  args::T 
end 

CollisionForce(;kwargs...) = CollisionForce{typeof(kwargs)}(kwargs)
#CollisionForce() = CollisionForce(NamedTuple())

function initialize(body::CollisionForce, nodes; 
  radius = Float32(1.0),
  strength = Float32(1.0), 
  iterations = 1,
  random = nothing)

  radius = _handle_node_values(nodes, radius)
  strength = _handle_node_values(nodes, strength)

  if random === nothing 
    random = Random.GLOBAL_RNG
  end 

  return InitializedCollisionForce(radius, strength, iterations, random)
end

struct InitializedCollisionForce
  radius
  strength
  iterations
  rng
end

function Base.show(io::IO, z::InitializedCollisionForce)
  print(io, "CollisionForce with ", z.iterations, " iterations")
  println(io)
  print(io, "  with radius ", z.radius)
  println()
  print(io,  " and strength ", z.strength)
end

function _walk_maxradius(T::KDTree, n::Int, idx::Int, radii, maxradius) 
  if NearestNeighbors.isleaf(n, idx)
    idxmap = T.indices
    maxrad = zero(eltype(maxradius))
    for ptsidx in NearestNeighbors.get_leaf_range(T.tree_data, idx)
      # we need to get the original index in the pts array, not the
      # index in the tree, which has likely been reordered. 
      #@show ptsidx, T.data[ptsidx], radii[ptsidx], idxmap[ptsidx], radii[idxmap[ptsidx]]
      origidx = T.reordered == false ? ptsidx : idxmap[ptsidx] 
      maxrad = max(maxrad, radii[origidx]) 
    end 
    return eltype(maxradius)(maxrad)
  else 
    left, right = NearestNeighbors.getleft(idx), NearestNeighbors.getright(idx)

    l_maxrad = _walk_maxradius(T, n, left, radii, maxradius)
    r_maxrad = _walk_maxradius(T, n, right, radii, maxradius)

    maxradius[idx] = max(l_maxrad, r_maxrad)

    return maxradius[idx]
  end 
end

function _build_tree_info_maxradius(T::KDTree, pts, radii)
  n = length(T.nodes) 
  maxradius = Vector{eltype(radii)}(undef, n) 
  
  _walk_maxradius(T, n, 1, radii, maxradius)
  return maxradius 
end 

"""
    _check_if_possible_collision(region::HyperRectangle, maxradius::Float64, targetpt)

Check for a potential collision between an expanded `region` and `targetpt`.
`region` is a `HyperRectangle`, and `maxradius` is the amount by which the `region` is expanded.
Returns `true` if a collision is possible, `false` otherwise.

  # Thanks ChatGPT! 
"""
function _check_if_possible_collision(region, maxradius, targetpt)
    # Expand the region by maxradius
    expanded_region = NearestNeighbors.HyperRectangle(
        region.mins .- maxradius,  # Subtract maxradius from each dimension 
        region.maxes .+ maxradius  # Add maxradius to each dimension 
    )

    # Check if the target point is inside the expanded region
    return all(expanded_region.mins .<= targetpt) && all(targetpt .<= expanded_region.maxes)
end


function _collision_force_on_node(target, treenode, rect, targetpt, T, maxradii, radii, strengths, rng, vel, velidx)
  if NearestNeighbors.isleaf(length(T.nodes), treenode)
    idxmap = T.indices
    for ptsidx in NearestNeighbors.get_leaf_range(T.tree_data, treenode)
      origidx = T.reordered == false ? ptsidx : idxmap[ptsidx] 
      # TODO, check if it's really better to use the symmetric approach. 
      if origidx > velidx # we only handle "half" of the positions and apply forces symmetrically...
        ri = radii[velidx]
        rj = radii[origidx] 
        r = ri + rj
        d = targetpt .- T.data[ptsidx] .- vel[origidx]
        d2 = dot(d,d)
        if d2 < r*r
          #println("Collision between ", velidx, " and ", origidx, " with distance ", sqrt(d2), " and radii ", ri, " and ", rj)
          # we have a collision. 
          d = jiggle(d, rng)
          d2 = dot(d,d)
          dval = sqrt(d2)
          l = (r-dval) / dval
          l *= strengths[velidx]

          factor = (rj*rj)/(ri*ri + rj*rj) 

          vel[velidx] = vel[velidx] .+ d .* l .* factor 
          vel[origidx] = vel[origidx] .- d .* l .* (1-factor)
          
          #vel[velidx] = vel[velidx] .+ d .* l .* (1-factor)
          #vel[origidx] = vel[origidx] .- d .* l .* (factor)
        end
      end
    end 
  else 
    maxradius = maxradii[treenode]
    if _check_if_possible_collision(rect, maxradius+radii[velidx], targetpt)
      left, right = NearestNeighbors.getleft(treenode), NearestNeighbors.getright(treenode)
      node = T.nodes[treenode]
      split_val = node.split_val
      split_dim = node.split_dim
      rect_right = NearestNeighbors.HyperRectangle(@inbounds(setindex(rect.mins, split_val, split_dim)), rect.maxes)
      rect_left = NearestNeighbors.HyperRectangle(rect.mins, @inbounds setindex(rect.maxes, split_val, split_dim))

      _collision_force_on_node(target, left, rect_left, targetpt, T, maxradii, radii, strengths, rng, vel, velidx)
      _collision_force_on_node(target, right, rect_right, targetpt, T, maxradii, radii, strengths, rng, vel, velidx)
    end 
  end
end 


function _apply_collsion_force(T, vel, maxradii, radii, strengths, rng)
  for i in eachindex(T.data)
    velidx = T.reordered == false ? i : T.indices[i]  # this is the index of i in the real vel array

    _collision_force_on_node(i, 1, T.hyper_rec, T.data[i] .+ vel[velidx], T, maxradii, radii, strengths, rng, vel, velidx)
  end 
end


function collisionforce!(niter::Int, alpha::Real, nodes, pos, vel, radii, strengths, rng)
  T = KDTree(pos; reorder=true)
  # need to find the biggest radius in each quadtree node. 
  maxradius = _build_tree_info_maxradius(T, pos, radii)
  for _ in 1:niter
    _apply_collsion_force(T, vel, maxradius, radii, strengths, rng)
  end
end


function simplecollisionforce!(niter::Int, alpha::Real, nodes, pos, vel, radii, strengths, rng)
  for _ in 1:niter
    for i in eachindex(nodes)
      targetpt = pos[i] .+ vel[i]
      for j in eachindex(nodes)
        if i > j 
          ri = radii[i]
          rj = radii[j]
          r = ri + rj
          d = targetpt .- pos[j] .- vel[j]
          d2 = dot(d,d)
          if d2 < r*r
            d = jiggle(d, rng)
            d2 = dot(d,d)
            dval = sqrt(d2)
            l = (r-dval) / dval
            factor = (rj*rj)/(ri*ri + rj*rj) 
            vel[i] = vel[i] .+ d .* l .* (factor)
            vel[j] = vel[j] .- d .* l .* (1-factor)
          end
        end
      end
    end
  end
end 


function force!(alpha::Real, sim::ForceSimulation, many::InitializedCollisionForce)
  pos = sim.positions
  vel = sim.velocities
  nodes = sim.nodes

  radii = many.radius
  strengths = many.strength
  rng = many.rng

  collisionforce!(many.iterations, alpha, nodes, pos, vel, radii, strengths, rng)
  #simplecollisionforce!(many.iterations, alpha, nodes, pos, vel, radii, strengths, rng)
end

