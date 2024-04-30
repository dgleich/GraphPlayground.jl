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
  center = 0 .* first(centers)
  weight = zero(eltype(weights))
  CType = typeof(center)
  WType = typeof(weight)
  if NearestNeighbors.isleaf(n, idx)
    idxmap = T.indices
    treepts = T.data 
    npts = 0 
    for ptsidx in NearestNeighbors.get_leaf_range(T.tree_data, idx)
      npts += 1
      Tidx = T.reordered ? ptsidx : idxmap[ptsidx]
      origidx = T.reordered == false ? ptsidx : idxmap[ptsidx] 
      center = center .+ treepts[Tidx]
      weight += strengths[origidx] 
    end 
    center = center ./ npts
    return (center::CType, weight::WType)
  else 
    left, right = NearestNeighbors.getleft(idx), NearestNeighbors.getright(idx)

    node = T.nodes[idx]
    split_val = node.split_val
    split_dim = node.split_dim
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
  n = length(T.nodes) 
  centers = Vector{Point2f}(undef, n)
  weights = Vector{Float32}(undef, n)
  widths = Vector{Float32}(undef, n)
  # we need to do a post-order traversal
  
  _walk(T, n, 1, centers, weights, widths, strengths, T.hyper_rec)
  return centers, weights, widths 
end 

@inline function _compute_force(rng, pt1, pt2, strength::T, max_distance2::T, min_distance2::T, alpha::T) where {T <: Real} 
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
  if NearestNeighbors.isleaf(length(T.nodes), treeindex)
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
  println(io)
  print(io, "  with strength ", z.strengths)
  println(io)
  print(io, "  with min_distance2 ", z.min_distance2)
  println(io)
  print(io, "  with max_distance2 ", z.max_distance2)
  println(io)
  print(io, "  with theta2 ", z.theta2)
end 
