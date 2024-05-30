
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
    p.node_size[][idx] = state ? 20 : 10
    p.node_size[] = p.node_size[] # trigger observable
  end
  nhover = NodeHoverHandler(node_hover_action)
  register_interaction!(ax, :nhover, nhover)

  function edge_hover_action(state, idx, event, axis)
    p.edge_width[][idx]= state ? 5.0 : 2.0
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
  kwargs...)
  n = nv(g) 
  f = Figure()
  button_startstop = Button(f[1, 1], label="Animate", tellwidth=false)
  button_stop = Button(f[1, 2], label="Stop", tellwidth=false)
  button_reheat = Button(f[1, 3], label="Reheat", tellwidth=false)
  button_help = Button(f[1, 4], label="Show Help", tellwidth=false)
  ax = Axis(f[2, :])
  ax.limits = (0, 800, 0, 600)

  status = Label(f[3,:], text=" ", tellwidth=false)

  for _ in 1:initial_iterations
    step!(sim)
  end
  
  p = igraphplot!(ax, g, sim; graphplot_options...)    

  p[:node_pos][] = sim.positions
  
  taskref = Ref{Union{Nothing,Task}}(nothing)
  should_close = Ref(false)

  on(button_reheat.clicks) do _
    sim.alpha.alpha = min(sim.alpha.alpha * 10, 1.0)
  end

  on(button_startstop.clicks) do _
    if taskref[] === nothing
      taskref[] = @async begin
        while true
          sleep(1 / 60)

          step!(sim)
          p[:node_pos][] = sim.positions

          should_close[] && break
        end
        should_close[] = false
      end
    end
    Consume(true)
  end

  on(button_stop.clicks) do _
    if taskref[] !== nothing && !should_close[]
      should_close[] = true
      wait(taskref[])
      taskref[] = nothing
      #set_close_to!(sl, 0)
    end
    Consume(true)
  end

  on(button_help.clicks) do _
    #println("Help")
    status.text[] = "Drag to move nodes, reheat to restart the animation, hold Shift while dragging to fix a node"
    Consume(true)
  end
  f
end

function playground(g;
  link_options = (;iterations=1,distance=30), 
  center_options = NamedTuple(),
  charge_options = NamedTuple(),
  kwargs...
)
  sim = ForceSimulation(Point2f, vertices(g); 
    link=LinkForce(;edges=edges(g), link_options...), 
    #collide=CollisionForce(;radius=10),
    #center=CenterForce(Point2f(400, 300)),
    charge=ManyBodyForce(;charge_options...),
    center=PositionForce(;target=Point2f(400, 300), center_options),
    )
  playground(g, sim; kwargs...)
end
