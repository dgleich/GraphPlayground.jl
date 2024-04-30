


"""
    _eltype(x)

Create an _eltype function that also handles NTuple types. This is useful to avoid
  a dependency on explicit point types of static arrays. Since everything we can
  do can be done with NTuple types. This forwards to Base.eltype for all other types.
"""
_eltype(x) = Base.eltype(x) 
# Aqua detects this as having an unbound type 
#_eltype(::NTuple{N, T}) where {N, T} = T
# so we use this ugly hack from StaticArrays instead ... 
_TupleOf{T} = Tuple{T,Vararg{T}}
_eltype(::Union{_TupleOf{T}, Type{<:_TupleOf{T}}}) where {T} = T



"""
    jiggle(rng::AbstractRNG)

Generate a small random perturbation using the provided random number generator (`rng`). 
The perturbation is uniformly distributed between -0.5e-6 and 0.5e-6. This function is 
commonly used in simulations to avoid issues like division by zero when two objects 
have the exact same position.

# Examples
```julia
rng = MersenneTwister(123)
jiggle(rng)
```
"""
function jiggle(rng)
  return (rand(rng) - 0.5) * 1e-6
end

"""
    jiggle(x, rng::AbstractRNG)

Apply a small random perturbation to each element of the array `x` that equals zero, 
using the provided random number generator (`rng`). Non-zero elements of `x` are left 
unaltered. This is particularly useful in numerical simulations where exact zeroes may 
lead to singularities or undefined behaviors.

# Arguments
- `x`: An array of numeric values.
- `rng`: A random number generator instance.

# Examples
```julia
x = [0, 1, 0, 2]
rng = MersenneTwister(123)
jiggle(x, rng)
```
"""
function jiggle(x, rng::AbstractRNG) 
  return map(c -> c == 0 ? _eltype(c)(jiggle(rng)) : c, x)
end 

"""
    _srcdst(e)

Extract the source and destination identifiers from an edge structure `e`. This function 
is designed to be used internally within graph-related algorithms where edges need to 
be decomposed into their constituent nodes.

# Arguments
- `e`: An edge data structure containing `src` and `dst` fields.

# Examples
```julia
e = (src=1, dst=2)
_srcdst(e)
```
"""
function _srcdst(e)
  return e.src, e.dst
end

"""
    _srcdst(e::Tuple)

A variant of `_srcdst` that directly returns the tuple `e`, assuming it represents an edge 
with source and destination values. This overload is useful when edges are represented 
simply as tuples, without any encapsulating structure.

# Arguments
- `e`: A tuple representing an edge, where the first element is the source and the second 
  element is the destination.

# Examples
```julia
e = (1, 2)
_srcdst(e)
```
"""
function _srcdst(e::Tuple)
  return e
end




"""
A model of the cooling step in d3-force.
The stepper allows dynamic retargeting of the cooling factor, which is useful 
in simulations where you want to adjust behavior for user interaction or for 
incoming data. 

Once the stepper has reached it's minimum value, it will return zero for all
subsequent steps. 

Usage:
```julia
alpha = CoolingStepper()
for i=1:10
  println(step!(alpha))
end
alpha.alpha_target = 0.5 
for i=1:10
  println(step!(alpha))
end
alpha.alpha_target = 0.0
for i=1:10
  println(step!(alpha))
end
"""
mutable struct CoolingStepper{T <: Real}
  alpha::T
  alpha_min::T
  alpha_decay::T
  alpha_target::T
end 

function step!(stepper::CoolingStepper)
  # convert this code 
  #  alpha += (alphaTarget - alpha) * alphaDecay;  
  if (stepper.alpha <= stepper.alpha_min)
    return zero(typeof(stepper.alpha))
  else 
    stepper.alpha += (stepper.alpha_target - stepper.alpha) * stepper.alpha_decay
    return stepper.alpha 
  end 
end

function CoolingStepper(; alpha=1.0, alpha_min=0.001, alpha_decay=1 - alpha_min^(1/300), alpha_target=0.0)
  return CoolingStepper(alpha, alpha_min, alpha_decay, alpha_target)
end



function _handle_node_values(nodes, x::Function)
  return map(x, nodes)
end
function _handle_node_values(nodes, x::Real)
  return ConstArray(x, (length(nodes),))
end 
function _handle_node_values(nodes, x::Tuple)
  return ConstArray(x, (length(nodes),))
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


import Base.getindex, Base.size 
struct ConstArray{T,N} <: AbstractArray{T,N}
  val::T
  shape::NTuple{N,Int}
end
getindex(c::ConstArray, i::Int...) = c.val
size(c::ConstArray) = c.shape 

## Write a Base.show function for ConstArray
function Base.show(io::IO, c::ConstArray)
  print(io, "ConstArray of shape ", c.shape, " with value ", c.val)
end