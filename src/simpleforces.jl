
function _handle_node_values(nodes, x::Function)
  return map(x, nodes)
end
function _handle_node_values(nodes, x::Real)
  return range(x, x, length(nodes))
end 
function _handle_node_values(nodes, x::Union{AbstractArray,Dict})
  return x
end


function _handle_link_values(edges, f::Function)
  return map(x -> f(x[1],x[2], _srcdst(x[2])...), enumerate(edges))
end
function _handle_link_values(edges, x::Real)
  return range(x, x, length=length(edges))
end
function _handle_link_values(edges, x::Union{AbstractArray,Dict})
  return x
end



struct CenterForce{T, V <: Real}
  center::T
  strength::V
  args::@NamedTuple{}
end 
CenterForce(center) = CenterForce(center, 1.0, NamedTuple())
CenterForce(center, strength) = CenterForce(center, strength, NamedTuple())
CenterForce(;center, strength) = CenterForce(center, strength, NamedTuple()) 

function initialize(center::CenterForce, nodes; kwargs...)
  return center
end 

function centerforce!(n::Integer, pos, centertarget, strength)
  ptsum = 0 .* first(pos) # get a zero element of the same type as pos[1]
  w = one(_eltype(_eltype(pos)))/n
  for i in 1:n
    ptsum = ptsum .+ (w .* pos[i]) # can't use .+= because it Point2f isn't mutable 
  end
  ptcenter = ptsum # we handle the 1/n with the w now.
  centerdir = (ptcenter .- centertarget)*strength 
  for i in eachindex(pos) 
    pos[i] = pos[i] .- centerdir
  end
end

function force!(alpha::Real, sim::ForceSimulation, center::CenterForce) 
  pos = sim.positions
  centertarget = center.center
  strength = center.strength
  nodes = sim.nodes
  
  centerforce!(length(nodes), pos, centertarget, strength)
end 

function Base.show(io::IO, z::CenterForce)
  print(io, "CenterForce with center ", z.center, " and strength ", z.strength)
end 