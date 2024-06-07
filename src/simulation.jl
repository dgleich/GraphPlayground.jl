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
    ForceSimulation([PositionType,] nodes; [...]) 
    ForceSimulation(positions, nodes; [rng,] [alpha,] [velocity_decay,] forcelist...)

Create a force simulator for a set of positions. This evaluates and evolves the positions 
based on the forces applied. It is designed to be used with evaluating a dynamic force
directed graph layout including attractive forces for edges and repulsive forces for nodes. 
But it may have other uses as well. For instance, collision forces can be used to simulate
packed bubble charts with various radii. 

## Arguments 
- `nodes` is any array of nodes. This can be very simple, i.e. 1:n, or 
  a list of objects. The objects must be used consistent with other forces involved. 
- `PositionType` is the type of the positions. Using `Point2f` is recommended and the default 
- `positions` is an array of initial positions. The position type is determined by the elements of 
the array. 
- `forcelist` is a trailing list of forces. The names of these forces do not matter. 
  The order is the order in which they are applied. While forcelist is not syntactically
  required, it is semantically required as otherwise the simulation will not do anything.

## Optional Arguments
- `rng` is a random number generator. This is used for the initial positions and for 
  any random perturbations if there are degeneracies. The default is to use 
    a deterministic generator so that the results are reproducible.
- `alpha` is the cooling stepper. This is used to control the rate of convergence.
  See [`CoolingStepper`](@ref) for more information.
- `velocity_decay` is the factor by which the velocities are decayed each step.
  Setting this to 1 will not decay the velocities. Setting it to 0 will stop all motion.
  The default is 0.6.  

## Usage
Here is an example that packs balls of different sizes
into a region around the point (0,0). 
```julia
radii = 1:10
sim = ForceSimulation(1:10; 
  collide=CollisionForce(radius=radii, iterations=3),
  center=PositionForce(target=(0,0)))
initial_positions = copy(sim.positions) 
step!(sim, 100) # run 100 steps 
plot(sim.positions; markersize=(radii .- 0.5).*pi/1.11, 
  markerspace=:data, strokewidth=0.25, strokecolor=:white)  # weird 1.11 to get the right size, add 0.05 
```
## Forces
The list of forces can have silly names if you wish. The names are not used other than
  for display. For example, this is entirely valid:
```julia
sim = ForceSimulation(1:10; 
  collide=CollisionForce(radius=radii, iterations=3),
  push_nodes_to_middle=PositionForce(target=(0,0))
  push_nodes_to_offset=PositionForce(target=(10,10)))
```
Of course, that generates a very useless simulator.     

## Forces
- [`LinkForce`](@ref): This force applies a spring force to all edges in the graph. 
  The force is proportional to the distance between the nodes.
- [`ManyBodyForce`](@ref): This force applies a repulsive force between all nodes. 
  The force is proportional to the inverse square of the distance between the nodes.
- [`PositionForce`](@ref): This force applies a force to all nodes to move them to a target position. 
  This is useful for centering the graph or pushing nodes to the edge.
- [`CollisionForce`](@ref): This force applies a repulsive force between all positions. 
  The force is proportional to the sum of the radii of the nodes.
- [`CenterForce`](@ref): This force directly centers all the positions. 

## Data 
The simulator maintains the following data that are useful:
- `positions`: The current positions of the nodes.
- `velocities`: The current velocities of the nodes.
You can access these directly.

## Methods
To fix a node in place, use `fixnode!(sim, i, pos)`. To free a node, use `freenode!(sim, i)`.
To take a step, use `step!(sim)`. To take multiple steps, use `step!(sim, n)`.

## See also
[`step!`](@ref), [`fixnode!`](@ref), [`freenode!`](@ref), [`LinkForce`](@ref),
[`ManyBodyForce`](@ref), [`PositionForce`](@ref), [`CollisionForce`](@ref), [`CenterForce`](@ref)
"""
function ForceSimulation(positions, nodes; 
  rng=Random.MersenneTwister(0xd3ce), # 0xd34ce -> "d3-force" ? d3 - 4 - ce? 
  alpha = CoolingStepper(),
  velocity_decay = 0.6,
  kwargs...)
  n = length(nodes)
  T = eltype(positions)
  velocities = Vector{T}(undef, n)
  fill!(velocities, ntuple(i->0, length(first(positions)))) # fancy way of writing 0s
  forces = NamedTuple( map(keys(kwargs)) do f 
    f => initialize(kwargs[f], nodes; random=rng, kwargs[f].args...)
  end)
  fixed = falses(n)
  ForceSimulation(nodes, forces, positions, velocities, rng,
    alpha, velocity_decay, fixed
    )
end
function ForceSimulation(T::Type, nodes; 
    rng=Random.MersenneTwister(0xd3ce), # 0xd34ce -> "d3-force" ? d3 - 4 - ce? 
    kwargs...)
  # 0xd34ce -> "d3-force" ? d3 - 4 - ce? 
  n = length(nodes)
  positions = _initial_positions(T, nodes, rng)
  return ForceSimulation(positions, nodes; rng, kwargs...)
end 
ForceSimulation(nodes; kwargs...) = ForceSimulation(Point2f, nodes; kwargs...)

function _initial_positions(T, nodes, rng)
  n = length(nodes)
  pos = Vector{T}(undef, n)
  for i in 1:n
    pos[i] = sqrt(n) .* ntuple(i->rand(rng), length(first(pos)))
  end
  return pos
end

function simstep!(alpha, positions, velocities, forces, decay, fixed)
  for i in eachindex(positions)
    if fixed[i] == false
      velocities[i] = velocities[i] .* decay
      positions[i] = positions[i] .+ velocities[i]
    else
      velocities[i] = ntuple(i->0, length(velocities[i]))
    end 
  end
end

function apply_forces!(alpha, sim, forces)
  for f in forces
    force!(alpha, sim, f)
  end
end

"""
    step!(sim) # take one step 
    step!(sim, n) # take n steps 

Take a step of the force simulator. This will apply all forces in the order they were
added to the simulator. The forces are applied to the positions and velocities.
The velocities are then decayed by the `velocity_decay` factor.

See [`ForceSimulation`](@ref) for more information and an example. 
"""
function step!(sim::ForceSimulation)
  alpha = step!(sim.alpha)
  apply_forces!(alpha, sim, sim.forces)
  simstep!(alpha, sim.positions, 
    sim.velocities, sim.forces, sim.velocity_decay, sim.fixed
    )
  return sim
end

function step!(sim::ForceSimulation, n)
  for i in 1:n
    step!(sim)
  end
  return sim
end


"""
    fixnode!(sim::ForceSimulation, i, pos)

Fix the position of a node in the simulation. This will prevent the node from moving.
This importantly keeps the velocity of the node set to 0, which will prevent the node
from updating other implicit positions. 
"""
function fixnode!(sim::ForceSimulation, i, pos)
  sim.fixed[i] = true
  sim.positions[i] = pos
end

"""
    freenode!(sim::ForceSimulation, i)

Remove the fixed position of a node in the simulation. This will allow the node to move.    
"""    
function freenode!(sim::ForceSimulation, i)
  sim.fixed[i] = false
end

function Base.show(io::IO, z::ForceSimulation)
  println(io, length(z.nodes), "-node ForceSimulation ", pointtype(z), " with forces: ")
  for f in z.forces
    println(io, "  ", f)
  end
end 

pointtype(z::ForceSimulation) = eltype(z.positions)
_get_node_array(T::DataType, sim::ForceSimulation) = Vector{T}(undef, length(sim.nodes))
_get_node_array(T::DataType, nodes) = Vector{T}(undef, length(nodes))

