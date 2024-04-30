
"""
`CenterForce` represents a centering adjustment in a force simulation. 
it has two parameters: 

* `center`: The center of the force, which can be anything resembling a point
* `strength`: The strength of the force, which is a real number

Note that CenterForce directly applies the force to the 
positions of the nodes in the simulation instead of updating their velocities.

Use PositionForce to apply a force to the velocities of the nodes instead. 
(Also, please don't combine PositionForce and CenterForce.)

Examples:
---------
n = 
rad = 10*rand(100)
sim = ForceSimulation(Point2f, eachindex(rad);
    center=CenterForce(center, strength=1.0),
    collide=CollisionForce(radius=rad)
    )
p = scatter(sim.positions, markersize=rad)
for i in 1:100
    step!(sim)
    p[:node_pos][] = sim.positions
end    
"""    
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

struct PositionForce{T}
  args::T
end 
PositionForce(;kwargs...) = PositionForce{typeof(kwargs)}(kwargs)

struct InitializedPositionForce
  targets
  strengths
end 

function initialize(pforce::PositionForce, nodes;
  strength=0.1,
  target=(0,0), kwargs...)

  strengths = _handle_node_values(nodes, strength)

  # need to be careful with the center, because it could be a single value or a tuple
  targets = _handle_node_values(nodes, target)
  if targets === target 
    if length(targets) != length(nodes)
      targets = ConstArray(target, (length(nodes),))
    end 
  end
  
  return InitializedPositionForce(targets, strengths)
end 

function positionforce!(alpha, nodes, pos, vel, strengths, targets)
  for i in nodes
    p = pos[i]
    t = targets[i]
    s = strengths[i]
    # TODO if you just want a particular component to be forced to a particular value
    # the idea is that you could do that with an NaN mask on the points. 
    # isvalid = map(isnan, t) 
    # t2 = map(x->isnan(x) ? zero(_eltype(t))) : x, t)
    vel[i] = vel[i] .+ (t .- p) .* s .* alpha
  end 
end

function force!(alpha::Real, sim::ForceSimulation, pforce::InitializedPositionForce) 
  pos = sim.positions
  targets = pforce.targets
  strengths = pforce.strengths
  nodes = sim.nodes
  
  positionforce!(alpha, nodes, pos, sim.velocities, strengths, targets)
end 

function Base.show(io::IO, z::InitializedPositionForce)
  print(io, "PositionForce with targets ", z.targets, " and strength ", z.strengths)
end 