var documenterSearchIndex = {"docs":
[{"location":"","page":"Home","title":"Home","text":"CurrentModule = GraphPlayground","category":"page"},{"location":"#GraphPlayground","page":"Home","title":"GraphPlayground","text":"","category":"section"},{"location":"","page":"Home","title":"Home","text":"Documentation for GraphPlayground.","category":"page"},{"location":"","page":"Home","title":"Home","text":"","category":"page"},{"location":"","page":"Home","title":"Home","text":"Modules = [GraphPlayground]","category":"page"},{"location":"#GraphPlayground.CenterForce","page":"Home","title":"GraphPlayground.CenterForce","text":"CenterForce represents a centering adjustment in a force simulation.  it has two parameters: \n\ncenter: The center of the force, which can be anything resembling a point\nstrength: The strength of the force, which is a real number\n\nNote that CenterForce directly applies the force to the  positions of the nodes in the simulation instead of updating their velocities.\n\nUse PositionForce to apply a force to the velocities of the nodes instead.  (Also, please don't combine PositionForce and CenterForce.)\n\nExamples:\n\nn =  rad = 10*rand(100) sim = ForceSimulation(Point2f, eachindex(rad);     center=CenterForce(center, strength=1.0),     collide=CollisionForce(radius=rad)     ) p = scatter(sim.positions, markersize=rad) for i in 1:100     step!(sim)     p[:node_pos][] = sim.positions end    \n\n\n\n\n\n","category":"type"},{"location":"#GraphPlayground.CoolingStepper","page":"Home","title":"GraphPlayground.CoolingStepper","text":"A model of the cooling step in d3-force. The stepper allows dynamic retargeting of the cooling factor, which is useful  in simulations where you want to adjust behavior for user interaction or for  incoming data. \n\nOnce the stepper has reached it's minimum value, it will return zero for all subsequent steps. \n\nUsage: ```julia alpha = CoolingStepper() for i=1:10   println(step!(alpha)) end alpha.alphatarget = 0.5  for i=1:10   println(step!(alpha)) end alpha.alphatarget = 0.0 for i=1:10   println(step!(alpha)) end\n\n\n\n\n\n","category":"type"},{"location":"#GraphPlayground.ForceSimulation-Tuple{Any, Any}","page":"Home","title":"GraphPlayground.ForceSimulation","text":"ForceSimulation(T, nodes; link=LinkForce(edges))\n- nodes is any array of nodes. This can be very simple, i.e. 1:n, or \n  a list of objects. \n- kwargs are a list of forces.\n\n\n\n\n\n","category":"method"},{"location":"#GraphPlayground.LinkForce","page":"Home","title":"GraphPlayground.LinkForce","text":"LinkForce(edges) LinkForce(edges; strength=50) LinkForce(edges; strength=(i,e,src,dst)->val[src]*val[dst], distance=50)\n\n\n\n\n\n","category":"type"},{"location":"#GraphPlayground.ManyBodyForce","page":"Home","title":"GraphPlayground.ManyBodyForce","text":"ManyBodyForce() ManyBodyForce(strength=-50) ManyBodyForce(edges; strength=(src,dst)->val[src]*val[dst], distance, rng)\n\nstrength - the repulsive strength to use, defaults to -30\nrng - the random number generator to jiggle close points \nmin_distance2 - where to lower-bound force application \nmax_distance2 - where to cutoff force application \ntheta2 - where to apply the quadtree approximation \n\n\n\n\n\n","category":"type"},{"location":"#GraphPlayground.Window-Tuple{Function, Any}","page":"Home","title":"GraphPlayground.Window","text":"Window(loop::Function, scene; [title=\"GraphPlayground\", size=(800,800), kwargs...])\n\nCreate a window based on a scene. The window will run the provided loop function ever frame. The loop function should take a single argument, which is the time since the window was opened. This function is a fairly thin wrapper around GLMakie.Screen and GLMakie.display_scene!, but makes it easier to abstract in the future. \n\nParameters\n\nloop: A function that will be called every frame.  The function should take a single argument,  which is the time since the window was opened.\nscene: The scene to display in the window.\ntitle: The title of the window. Default is \"GraphPlayground\".\nsize: The size of the window. Default is (800,800).\nkwargs: Additional keyword arguments to pass to the GLMakie.Screen constructor.\n\nExample\n\nThis example shows a bunch of points that are going to be pushed away from each other in a simulation of a collision. \n\nusing GeometryBasics, GraphPlayground, GLMakie\nscenesize = 500 \nn = 100\nscene = Scene(camera=campixel!, size=(scenesize, scenesize))\npts = Observable((scenesize/2*rand(Point2f0, n)) .+ (scenesize/4)*Point2f(1,1))\nradius = rand(10:20, n)\nsim = ForceSimulation(pts[], eachindex(pts[]);\n  collide = CollisionForce(radius=radius .+ 2, iterations=3))\nscatter!(scene, pts, markersize=pi*radius/1.11)\nGraphPlayground.Window(scene; \n  title=\"Collision Simulation\", size=(scenesize, scenesize),\n  focus_on_show = true) do _ \n  step!(sim)\n  pts[] = sim.positions\nend \n\n\n\n\n\n","category":"method"},{"location":"#GraphPlayground._check_if_possible_collision-Tuple{Any, Any, Any}","page":"Home","title":"GraphPlayground._check_if_possible_collision","text":"_check_if_possible_collision(region::HyperRectangle, maxradius::Float64, targetpt)\n\nCheck for a potential collision between an expanded region and targetpt. region is a HyperRectangle, and maxradius is the amount by which the region is expanded. Returns true if a collision is possible, false otherwise.\n\nThanks ChatGPT!\n\n\n\n\n\n","category":"method"},{"location":"#GraphPlayground._eltype-Tuple{Any}","page":"Home","title":"GraphPlayground._eltype","text":"_eltype(x)\n\nCreate an _eltype function that also handles NTuple types. This is useful to avoid   a dependency on explicit point types of static arrays. Since everything we can   do can be done with NTuple types. This forwards to Base.eltype for all other types.\n\n\n\n\n\n","category":"method"},{"location":"#GraphPlayground._srcdst-Tuple{Any}","page":"Home","title":"GraphPlayground._srcdst","text":"_srcdst(e)\n\nExtract the source and destination identifiers from an edge structure e. This function  is designed to be used internally within graph-related algorithms where edges need to  be decomposed into their constituent nodes.\n\nArguments\n\ne: An edge data structure containing src and dst fields.\n\nExamples\n\ne = (src=1, dst=2)\n_srcdst(e)\n\n\n\n\n\n","category":"method"},{"location":"#GraphPlayground._srcdst-Tuple{Tuple}","page":"Home","title":"GraphPlayground._srcdst","text":"_srcdst(e::Tuple)\n\nA variant of _srcdst that directly returns the tuple e, assuming it represents an edge  with source and destination values. This overload is useful when edges are represented  simply as tuples, without any encapsulating structure.\n\nArguments\n\ne: A tuple representing an edge, where the first element is the source and the second  element is the destination.\n\nExamples\n\ne = (1, 2)\n_srcdst(e)\n\n\n\n\n\n","category":"method"},{"location":"#GraphPlayground.jiggle-Tuple{Any, Random.AbstractRNG}","page":"Home","title":"GraphPlayground.jiggle","text":"jiggle(x, rng::AbstractRNG)\n\nApply a small random perturbation to each element of the array x that equals zero,  using the provided random number generator (rng). Non-zero elements of x are left  unaltered. This is particularly useful in numerical simulations where exact zeroes may  lead to singularities or undefined behaviors.\n\nArguments\n\nx: An array of numeric values.\nrng: A random number generator instance.\n\nExamples\n\nx = [0, 1, 0, 2]\nrng = MersenneTwister(123)\njiggle(x, rng)\n\n\n\n\n\n","category":"method"},{"location":"#GraphPlayground.jiggle-Tuple{Any}","page":"Home","title":"GraphPlayground.jiggle","text":"jiggle(rng::AbstractRNG)\n\nGenerate a small random perturbation using the provided random number generator (rng).  The perturbation is uniformly distributed between -0.5e-6 and 0.5e-6. This function is  commonly used in simulations to avoid issues like division by zero when two objects  have the exact same position.\n\nExamples\n\nrng = MersenneTwister(123)\njiggle(rng)\n\n\n\n\n\n","category":"method"}]
}
