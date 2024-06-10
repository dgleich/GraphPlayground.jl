using GraphPlayground, StableRNGs, GeometryBasics

## Setup the nodes
rng = StableRNG(1)
nballs = 200
nnodes = nballs + 1
width = 564 
k = width/nnodes
radiusdist = k:4k
radius = rand(rng, radiusdist, nnodes )
radius[end] = 0

## Create the positions
pos = [Point2f0(rand(rng, 0:width), rand(rng, 0:width)) for _ in 1:nnodes]
pos = pos .- sum(pos) / length(pos) 


## Setup the force simulation 

sim = ForceSimulation(
  pos, # the starting list of positions 
  eachindex(pos); # the list of nodes, it's just all the indices. 
  position=PositionForce(;strength=0.01), # a centering force
  collide=CollisionForce(;radius=radius.+1,iterations=3), # the collision force 
  charge=ManyBodyForce(strength=(i) -> i==nnodes ? -width*2/3 : 0.0, theta2=0.82),
  # this creates a strong repulsion from the mouse pointer (which is the 
  # last node)
  alpha=GraphPlayground.CoolingStepper(alpha_target=0.3),
  velocity_decay=0.9,)

## Setup the scene and window
s = Scene(camera = campixel!, size = (width, width))
pos = Observable(sim.positions .+ Point2f0(width/2, width/2))
scatter!(s, 
  pos,
  markersize=pi*radius/1.11, 
  markerspace=:pixel, 
  color=:black,
  strokewidth=0.5, 
  strokecolor=:white, 
)
GraphPlayground.Window(s; title="Mouse Pointer Repulsion Demo") do _
  mp = mouseposition(s) # get the mouse position
  @show mp 
  fixnode!(sim, nnodes, mp .- Point2f0(width/2, width/2)) # fix the last node to the mouse pointer
  step!(sim) # take a step in the simulation
  pos[] = sim.positions .+ Point2f0(width/2, width/2) # update the positions
end 

## A few things for test cases
step!(sim) # directly take a step to exercise various portions
display(sim) 