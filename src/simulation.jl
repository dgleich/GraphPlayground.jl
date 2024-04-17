struct ForceSimulation
  nodes
  forces
  positions
  velocities
  rng::AbstractRNG
  alpha::CoolingStepper
  velocity_decay
  fixed
end 

"""
    ForceSimulation(T, nodes; link=LinkForce(edges))
    - nodes is any array of nodes. This can be very simple, i.e. 1:n, or 
      a list of objects. 
    - kwargs are a list of forces. 
"""
function ForceSimulation(T::Type, nodes; rng=Random.MersenneTwister(0xd3ce), 
    positions=nothing, 
    alpha = CoolingStepper(),
    velocity_decay = 0.6,
    kwargs...)
  # 0xd34ce -> "d3-force" ? d3 - 4 - ce? 
  n = length(nodes)
  if positions === nothing
    positions = rand(rng, T, n)
  end
  velocities = zeros(T, n)
  forces = NamedTuple( map(keys(kwargs)) do f 
    f => initialize(kwargs[f], nodes; random=rng, kwargs[f].args...)
  end)
  fixed = falses(n)
  ForceSimulation(nodes, forces, positions, velocities, rng,
    alpha, velocity_decay, fixed
    )
end 
ForceSimulation(nodes; kwargs...) = ForceSimulation(Tuple{Float32,Float32}, nodes; kwargs...)

function simstep!(alpha, positions, velocities, forces, decay, fixed)
  for i in eachindex(positions)
    if fixed[i] == falses
      positions[i] = positions[i] .+ velocities[i]
      velocities[i] = velocities[i]*decay
    end 
  end
end

function apply_forces!(alpha, sim, forces)
  for f in forces
    force!(alpha, sim, f)
  end
end

function step!(sim::ForceSimulation)
  alpha = step!(sim.alpha)
  apply_forces!(alpha, sim, sim.forces)
  simstep!(alpha, sim.positions, 
    sim.velocities, sim.forces, sim.velocity_decay, sim.fixed
    )
end

function fixnode!(sim::ForceSimulation, i, pos)
  sim.fixed[i] = true
  sim.positions[i] = pos
end

function freenode!(sim::ForceSimulation, i)
  sim.fixed[i] = false
end

function Base.show(io::IO, z::ForceSimulation)
  println(io, length(z.nodes), "-node ForceSimulation ", pointtype(z), " with forces: ")
  for f in z.forces
    println(io, "  ", f)
  end
end 

pointtype(z::ForceSimulation) = eltype(z)
_get_node_array(T::DataType, sim::ForceSimulation) = Vector{T}(undef, length(sim.nodes))
_get_node_array(T::DataType, nodes) = Vector{T}(undef, length(nodes))

