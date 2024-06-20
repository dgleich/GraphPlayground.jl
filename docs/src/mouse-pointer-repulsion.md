```@meta
CurrentModule = GraphPlayground
```

# Mouse Pointer Collsion Demo
This is a port of the 
[mouse pointer repulsion demo from the d3-force library](https://d3js.org/d3-force/collide) to Julia as an example of how the library works.

## Required packages
```
using GraphPlayground, StableRNGs, GeometryBasics, GLMakie
```
We use GeometryBasics for the `Point2f` type. 

## Setup the nodes.
There are going to be `n+1` nodes in our simulation. `n` for each ball 
and `1` for the mouse pointer.  These parameters come from the d3 demo. 

In this case, we allocate one extra node and set it's radius to 1.
This is going to represent the mouse pointer. 

```
rng = StableRNG(1)
nballs = 200
nnodes = nballs + 1
width = 564 
k = width/nnodes
radiusdist = k:4k
radius = rand(rng, radiusdist, nnodes )
radius[end] = 1
```

**Generate initial positions**
We generate random initial positions without concern for any collisions
or overlaps, etc. 
```
pos = [Point2f0(rand(rng, 0:width), rand(rng, 0:width)) for _ in 1:nnodes]
pos = pos .- sum(pos) / length(pos) 
```

## Setup the simulation
We setup the [`ForceSimulation`](@ref) now. This is going
to have a centering force to keep everything at (0,0). 
We are going to model collisions for all of the nodes, except
with the radius grown by 1 so that they shouldn't look like
they are touching. 
Finally, we need to setup the repulsion for the mouse pointer.
This is done by setting strength for each node to `0` except
for the last node. For this one we model a strong repulsive
force by setting strength to `-width*2/3` (recall that 
negative strength corresponds to repulsion). 

The last thing we change in this simulation is the 
`alpha` option. (Maybe I need a better parameter name.)
This controls the simulation "cooling",
or how we want to force the simulation to settle even if
it might not want to settle. In this case, we want to keep
the simulation fairly "hot", which means we set a target
value of alpha to be `0.3`. 

Finally, to mirror the dynamics of the _d3-force_ example, 
we set the velocity decay to `0.9`. 

```
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
```

A few notes, as pointed out in a few places, the _names_ of each
force do not matter. We simply treat them as a list. The names
are meant to help you, the user understand what you are doing or
communicate with others. For instance, the following is also fine.
(But really, don't do this... )

```
sim = ForceSimulation(
  pos, # the starting list of positions 
  eachindex(pos); # the list of nodes, it's just all the indices. 
  gamma=PositionForce(;strength=0.01), # a centering force
  delta=CollisionForce(;radius=radius.+1,iterations=3), # the collision force 
  theta=ManyBodyForce(strength=(i) -> i==nnodes ? -width*2/3 : 0.0, theta2=0.82),
  # this creates a strong repulsion from the mouse pointer (which is the 
  # last node)
  alpha=GraphPlayground.CoolingStepper(alpha_target=0.3),
  velocity_decay=0.9)
```

## Linking the simulation to a Makie window and keeping it updated. 
Setting up the scene. We first setup a Makie scene to display the 
dots. This is "standard" dynamic Makie. In this case, we create 
a scene. Then we create an Observable array based on the 
random initial positions. The idea is that we can update
the positions based on the simulation. We setup the plot
with a simple scatter. There is a weird scaling to get
the radius draw the same way. This was determined by trial
and error to get a radius of 10 to look correct. 
Each ball will have a small stroke as well. (This is why
we need the extra 1 pixel of width in the collision force.)

```
s = Scene(camera = campixel!, size = (width, width))
pos = Observable(sim.positions .+ Point2f0(width/2, width/2))
scatter!(s, 
  pos,
  markersize=pi*radius/1.11, # weird scaling to get size right 
  markerspace=:pixel, 
  color=:black,
  strokewidth=0.5, 
  strokecolor=:white, 
)
```

Now, the heart of this is setting up an update loop. There seems
to be no good way to do this in Makie without create a Screen yourself.
So we setup a `Window` function to make it easier. The `Window` function
takes an update function that gets run every frame. (For the Makie 
afficionados, this is mapped to the `on(screen.render_tick)` function.)


```
function update(_) # we don't use the argument 
  mp = mouseposition(s) # get the mouse position
  fixnode!(sim, nnodes, mp .- Point2f0(width/2, width/2)) # fix the last node to the mouse pointer
  step!(sim) # take a step in the simulation
  pos[] = sim.positions .+ Point2f0(width/2, width/2) # update the positions
end 
GraphPlayground.Window(update, s;
  title="Mouse Pointer Repulsion Demo")
```

Of course, Julia supports the slick equivalent syntax to make this easier to write:
```
GraphPlayground.Window(s; title="Mouse Pointer Repulsion Demo") do _
  mp = mouseposition(s) # get the mouse position
  @show mp 
  fixnode!(sim, nnodes, mp .- Point2f0(width/2, width/2)) # fix the last node to the mouse pointer
  step!(sim) # take a step in the simulation
  pos[] = sim.positions .+ Point2f0(width/2, width/2) # update the positions
end 
```

And we have our 



We want the simulation to advance at a regular rate. For this reason, 
we created a Window type that creates a `GLMakie` window with a regular 
update

```
Window()


  
