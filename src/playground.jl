
function igraphplot!(ax, g, sim; kwargs...)
  p = graphplot!(ax, g; 
              edge_width = [2.0 for i in 1:ne(g)],
              edge_color = [colorant"gray" for i in 1:ne(g)],
              node_size = [10 for i in 1:nv(g)],
              node_color = [colorant"black" for i in 1:nv(g)], 
              layout = sim.positions, 
              kwargs...)
  
  hidedecorations!(ax); hidespines!(ax)
  ax.aspect = DataAspect()
  deregister_interaction!(ax, :rectanglezoom)
  
  function node_hover_action(state, idx, event, axis)
    p.node_size[][idx] = state ? p.node_size[][idx]*2 : p.node_size[][idx]/2
    p.node_size[] = p.node_size[] # trigger observable
  end
  nhover = NodeHoverHandler(node_hover_action)
  register_interaction!(ax, :nhover, nhover)

  function edge_hover_action(state, idx, event, axis)
    p.edge_width[][idx]= state ? p.edge_width[][idx]*4 : p.edge_width[][idx]/4
    p.edge_width[] = p.edge_width[] # trigger observable
  end
  ehover = EdgeHoverHandler(edge_hover_action)
  register_interaction!(ax, :ehover, ehover)

  function node_drag_action(state, idx, event, axis)
    if state == false
      # this means it's the end of the drag
      if Keyboard.left_shift in events(axis).keyboardstate
        # then we want to leave the node as fixed...
      else 
        freenode!(sim, idx)
      end 
      sim.alpha.alpha_target = 0.001
    else 
      fixnode!(sim, idx, event.data)
      sim.alpha.alpha_target = 0.3
      #p[:node_pos][][idx] = event.data
      p[:node_pos][] = p[:node_pos][]
    end 
  end
  ndrag = NodeDragHandler(node_drag_action)
  register_interaction!(ax, :ndrag, ndrag)

  return p
end 

function playground(g, sim::ForceSimulation; 
  initial_iterations = 10,
  graphplot_options = NamedTuple(),
  labels = map(i->string(i), 1:nv(g)),
  verbose = false)

  f = Figure()
  button_startstop = Button(f[1, 1], label="Animate", tellwidth=false)
  button_reheat = Button(f[1, 3], label="Reheat", tellwidth=false)
  button_help = Button(f[1, 4], label="Show Help", tellwidth=false)
  ax = Axis(f[2, :])
  ax.limits = (0, 800, 0, 600)

  txt = text!(ax, (0, 0), text="")

  status = Label(f[3,:], text="", tellwidth=false,
    tellheight=true, height=1)

  for _ in 1:initial_iterations
    step!(sim)
  end
  
  p = igraphplot!(ax, g, sim; graphplot_options...)    

  function node_hover_action_label(state, idx, event, axis)
    status.text[] = state ? "Node $(labels[idx])" : ""
  end
  register_interaction!(ax, :nhover_label, NodeHoverHandler(node_hover_action_label))

  edgelist = collect(edges(g))

  function edge_hover_action_label(state, idx, event, axis)
    edge = edgelist[idx]
    status.text[] = state ? "Edge $(labels[edge.src]) -- $(labels[edge.dst])" : ""
  end
  register_interaction!(ax, :ehover_label, EdgeHoverHandler(edge_hover_action_label))

  p[:node_pos][] = sim.positions
  run_updates = Ref(false)
  
  on(button_reheat.clicks) do _
    sim.alpha.alpha = min(sim.alpha.alpha * 10, 1.0)
  end

  on(button_startstop.clicks) do _
    if button_startstop.label[] == "Animate"
      run_updates[] = true 
      button_startstop.label[] = "Stop Updates"
    else
      run_updates[] = false
      button_startstop.label[] = "Animate"
    end 
    Consume(true)
  end

  
  on(button_help.clicks) do _
    #println("Help")
    status.text[] = "Drag to move nodes, reheat to restart the animation, hold Shift while dragging to fix a node"
    Consume(true)
  end

  w = Window(f.scene, focus_on_show=true, framerate=60.0, 
    vsync=true, render_on_demand=false, title="GLMakie Graph Playground") do _
    if run_updates[] == true 
      step!(sim)
      p[:node_pos][] = sim.positions
      if verbose 
        txt.text[] = "alpha $(sim.alpha.alpha)"
      end 
    end 
  end 

  return Playground(w, sim, ax)
end

struct Playground{WindowType,SimType,AxisType}
  window::WindowType
  sim::SimType
  axis::AxisType
end

import Base.display
display(p::Playground) = display(p.window)
import Base.show 
show(io::IO, p::Playground) = println(io, "Playground with window ", p.window, " and simulation ", p.sim)


"""
    playground(g; 
      [link_options = (;iterations=1,distance=30),] 
      [center_options = NamedTuple(),]
      [charge_options = NamedTuple(),]
      [graphplot_options = NamedTuple(),]
      [initial_iterations = 10,]
      [labels = map(i->string(i), 1:nv(g)),]
      [verbose = false,]
      [kwargs...] )
    playground(g, sim; kwargs...)

Create a graph playground window from the graph `g`.

The value that is returned is a `Playground` object, which is a thin 
wrapper around the window, the simulation, and the Makie axis.

## Optional parameters
- `link_options`: These options are passed to the `LinkForce`` constructor. 
  The default is `(;iterations=1,distance=30)`. This is generally good.
  For grid graphs, set iterations higher to get a better layout.
- `center_options`: These options are passed to the `PositionForce` constructor.
- `charge_options`: These options are passed to the `ManyBodyForce` constructor.
- `graphplot_options`: These options are passed to the `graphplot!` function.
- `initial_iterations`: The number of layout iteration to run before the first display.
  The default is 10. 
- `labels`: A list of strings to display for the node identifiers. By default these 
  are the numeric node ids
- `verbose`: If true, additional information is shown in the lower left corner of the plot.

## Examples
```julia
g = wheel_graph(10)
playground(g)
```

For a grid, this often looks much better
```julia
g = grid([10,10])
playground(g; 
  link_options=(;iterations=10, strength=1, distance=20))
```

## See also
[`ForceSimulation`](@ref), [`LinkForce`](@ref), [`ManyBodyForce`](@ref), [`PositionForce`](@ref)
"""
function playground(g;
  link_options = (;iterations=1,distance=30), 
  center_options = NamedTuple(),
  charge_options = NamedTuple(),
  kwargs...
)
  sim = ForceSimulation(Point2f, vertices(g); 
    link=LinkForce(;edges=edges(g), link_options...), 
    charge=ManyBodyForce(;charge_options...),
    center=PositionForce(;target=Point2f(400, 300), center_options),
    )
  playground(g, sim; kwargs...)
end
