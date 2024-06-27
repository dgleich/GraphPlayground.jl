"""
    ManyBodyForce()
    ManyBodyForce(; [strength], [min_distance2], [max_distance2], [theta2], [random])

Create a force defined by multiple bodies. 
This force is used to simulate the repulsion or attraction
between nodes of the simulation. If you wish to apply to only 
a subset of nodes, you can set the `strength` to zero for the
nodes you wish to ignore. 

This computation is implemented with a space partitioning data structure
(current a KDTree) to approximate the impact of distance forces
using a far-field approximation (this is often called a 
Barnes-Hut approximation, but that doesn't help understand what
is going on). Setting `theta2` to zero will cause it to 
discard the approximation and compute the exact force. 
Reasonable values for `theta2` are between 0.5 (better approximation) 
and 1.5 (poor approximation). (This is the square of the ``\\theta``
value commonly used in Barnes-Hut approximations.)

## Arguments
- `strength`: A constant, a function or array of values.
  The repulsive strength to use, defaults to -30, 
  which is a repulsive force between nodes. 
- `min_distance2`: A constant, that defines a minimum distance
  between nodes. If the distance between two nodes is less than
  this value, the force is increased a bit. The default is 1.0.
- `max_distance2`: A constant, that defines a maximum distance
  between nodes. If the distance between two nodes is greater than
  this value, the force is ignored. The default is Inf.
- `theta2`: A constant, that defines the accuracy of the approximation.
  The default is 0.81, which is a reasonable value for most simulations.
- `random`: A random number generator. This is used for the random perturbations.      
"""
struct ManyBodyForce{T}
  args::T 
end 
ManyBodyForce(;kwargs...) = ManyBodyForce{typeof(kwargs)}(kwargs)

struct InitializedManyBodyForce
  strengths
  min_distance2
  max_distance2
  theta2
  rng
end

function initialize(body::ManyBodyForce, nodes; 
  strength = Float32(-30.0), 
  min_distance2 = Float32(1.0),
  max_distance2 = Float32(Inf),
  theta2 = Float32(0.81),
  random = nothing)

  strength = _handle_node_values(nodes, strength)

  return InitializedManyBodyForce(strength, min_distance2, max_distance2, theta2, random)
end

#=
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
=#

function _walk(T::KDTree, n::Int, idx::Int, centers, weights, widths, strengths, rect) 
  center = _zero(eltype(centers)) # handles Tuple types... 
  weight = zero(eltype(weights))
  CType = typeof(center)
  WType = typeof(weight)
  FType = _eltype(eltype(centers))
  if NearestNeighbors.isleaf(n, idx)
    idxmap = T.indices
    treepts = T.data 
    totalmass = zero(FType)
    for ptsidx in NearestNeighbors.get_leaf_range(T.tree_data, idx)
      Tidx = T.reordered ? ptsidx : idxmap[ptsidx]
      origidx = T.reordered == false ? ptsidx : idxmap[ptsidx] 
      q = FType(abs(strengths[origidx]))
      totalmass += q
      center = center .+ q*treepts[Tidx]
      weight += strengths[origidx] 
    end 
    center = center ./ totalmass
    return (center::CType, weight::WType)
  else 
    left, right = NearestNeighbors.getleft(idx), NearestNeighbors.getright(idx)

    split_val = T.split_vals[idx]
    split_dim = T.split_dims[idx]
    rect_right = NearestNeighbors.HyperRectangle(@inbounds(setindex(rect.mins, split_val, split_dim)), rect.maxes)
    rect_left = NearestNeighbors.HyperRectangle(rect.mins, @inbounds setindex(rect.maxes, split_val, split_dim))

    lcenter, lweight = _walk(T, n, left, centers, weights, widths, strengths, rect_left)
    rcenter, rweight = _walk(T, n, right, centers, weights, widths, strengths, rect_right)

    centers[idx] = (abs(lweight) .* lcenter .+ abs(rweight) .* rcenter) ./ (abs(lweight) .+ abs(rweight))
    weights[idx] = lweight + rweight
    widths[idx] = maximum(rect.maxes .- rect.mins)
    return (centers[idx]::CType, weights[idx]::WType)
  end 
end

function _build_tree_info(T::KDTree, pts, strengths)
  n = T.tree_data.n_internal_nodes
  centers = Vector{eltype(pts)}(undef, n)
  weights = Vector{eltype(strengths)}(undef, n)
  widths = Vector{_eltype(eltype(pts))}(undef, n)
  # we need to do a post-order traversal
  
  _walk(T, n, 1, centers, weights, widths, strengths, T.hyper_rec)
  return centers, weights, widths 
end 

@inline function _compute_force(rng, pt1, pt2, strength, max_distance2, min_distance2, alpha) 
  d = pt2 .- pt1
  d = jiggle(d, rng)
  d2 = dot(d, d)

  if d2 < max_distance2
    #d = jiggle(d, rng)
    if d2 < min_distance2
      @fastmath d2 = sqrt(min_distance2*d2)
    end

    w = strength*alpha / d2
    return d .* w 
  else
    return 0 .* pt1 
  end 
end 

function _compute_force_on_node(target, treeindex, targetpt, T, forcefunc, centers, weights, widths, strengths, theta2, vel, velidx)
  #f = 0 .* targetpt
  ncomp = 0 
  if NearestNeighbors.isleaf(T.tree_data.n_internal_nodes, treeindex)
    idxmap = T.indices
    treepts = T.data 
    f = 0 .* targetpt
    @simd for Tidx in NearestNeighbors.get_leaf_range(T.tree_data, treeindex)    
      #ptsidx = idxmap[Tidx]
      #Tidx = T.reordered ? Tidx : ptsidx
      if Tidx != target 
        ncomp += 1
        @inbounds pt = treepts[Tidx]
        origidx = T.reordered == false ? Tidx : idxmap[Tidx]
        f = f .+ forcefunc(targetpt, pt, strengths[origidx])
      end 
    end 
    @inbounds vel[velidx] = vel[velidx] .+ f
  else 
    @inbounds center = centers[treeindex]
    @inbounds w = weights[treeindex]
    @inbounds width = widths[treeindex]

    d = center .- targetpt
    d2 = dot(d,d)

    if (width*width / theta2) < d2 
      @inbounds vel[velidx] = vel[velidx] .+ forcefunc(targetpt, center, w)
      ncomp += 1
      # and then don't recurse... 
    else 
      # otherwise, recurse... 
      left, right = NearestNeighbors.getleft(treeindex), NearestNeighbors.getright(treeindex)

      ncomp += _compute_force_on_node(target, left, targetpt, T, forcefunc, centers, weights, widths, strengths, theta2, vel, velidx)
      ncomp += _compute_force_on_node(target, right, targetpt, T, forcefunc, centers, weights, widths, strengths, theta2, vel, velidx)
    end 
  end
  return ncomp
end 

function _applyforces!(T, vel, centers, weights, widths, strengths, forcefunc, theta2)
  ncomp = 0 
  for i in eachindex(T.data)
    velidx = T.reordered == false ? i : T.indices[i]  # this is the index of i in the real vel array
    ncomp += _compute_force_on_node(i, 1, T.data[i], T, forcefunc, centers, weights, widths, strengths, theta2, vel, velidx)
  end 
end

function manybodyforce!(alpha::Real, nodes, pos, vel, strengths, min_distance2, max_distance2, theta2, rng)
  T = KDTree(pos)
  centers, weights, widths = _build_tree_info(T, pos, strengths)
  forcefunc = @inline (u, v, strength) -> _compute_force(rng, u, v, strength, max_distance2, min_distance2, Float32(alpha))
  _applyforces!(T, vel, centers, weights, widths, strengths, forcefunc, theta2)
end

function simpleforces!(alpha::Real, nodes, pts, vel, strengths, min_distance2, max_distance2, theta2, rng)
  forcefunc = @inline (u, v, strength) -> _compute_force(rng, u, v, strength, max_distance2, min_distance2, Float32(alpha))
  for i in eachindex(pts)
    targetpt = pts[i]
    f = 0.0 .* targetpt 
    
    for j in eachindex(pts)
      if i != j
        f = f .+ forcefunc(targetpt, pts[j], strengths[j])
      end 
    end
    vel[i] = vel[i] .+ f
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
  #simpleforces!(alpha, nodes, pos, vel, strengths, min_distance2, max_distance2, theta2, rng)
end

function Base.show(io::IO, z::InitializedManyBodyForce)
  print(io, "ManyBodyForce")
  println(io)
  print(io, "  with strength ", z.strengths)
  println(io)
  print(io, "  with min_distance2 ", z.min_distance2)
  println(io)
  print(io, "  with max_distance2 ", z.max_distance2)
  println(io)
  print(io, "  with theta2 ", z.theta2)
end 
