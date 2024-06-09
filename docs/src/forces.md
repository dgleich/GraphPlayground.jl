```@meta
CurrentModule = GraphPlayground
```

# Forces

The [`ForceSimulator`](@ref) is the key dynamics implementation. It is hugely inspired
by the excellent `d3-force` library. It's setup for nice displays instead
of scientific accuracy. This includes things like
- randomly jiggles to avoid singularities. 
- graceful fallbacks and approximations.

## How to give information about the data or graph to influence the forces

[`LinkForce`](@ref) takes information about edges along with a number of 
additional optional weights. If you wish to specify them yourself you can 
provide

- *a constant*. This constant is used for all edges
- *an array*. The array needs to have the same order as the edge input array. 
- *a function*. The function is computed once and turned into the array by calling
  the function for each edge. The function must take the following arguments:
    `(i,e,src,dst)` where
    This is called with 
    - `i`: The index of the edge in the edges array.
    - `e`: The edge structure.
    - `src`: The source node.
    - `dst`: The destination node.
You can use this interface for the `distance`, `strength`, and `bias`. 

[`ManyBodyForce`](@ref) takes in a `strength` argument that determines
the impact on each node. If this is positive, the effect
is attractive to the node. If it is negative, the effect is repulsive 
from the node. As before, this can be 
- *a constant*. This constant is used for all nodes
- *an array*. The array needs to have the same order as the node input array. 
- *a function*. The function is computed once and turned into the array by calling
  the function for each node. The function is actually just a `map` over the 
  `nodes` input to the force simulation, as in `map(f, nodes)`. 

[`PositionForce`](@ref) takes in a `target` argument that determines
the target postion for each node. 
- *a constant*. This constant position is used for all nodes
- *an array*. The array of positions which needs to have the same order 
  as the node input array. 
- *a function*. The function is computed once and turned into the array by calling
  the function for each node. The function is actually just a `map` over the 
  `nodes` input to the force simulation, as in `map(f, nodes)`. 




