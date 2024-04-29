
function igraphplot!(ax, g, sim; kwargs...)
  p = graphplot!(ax, g, edge_width = [2.0 for i in 1:ne(g)],
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
      freenode!(sim, idx)
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

function playground(g;
  initial_iterations = 10)
  n = nv(g) 
  f = Figure()
  buta = Button(f[1, 1], label="Animate", tellwidth=false)
  buts = Button(f[1, 2], label="Stop", tellwidth=false)
  butr = Button(f[1, 3], label="Reheat", tellwidth=false)
  ax = Axis(f[2, :])
  ax.limits = (0, 800, 0, 600)
  
  sim = ForceSimulation(Point2f, vertices(g); 
    link=LinkForce(edges=edges(g)), 
    #center=CenterForce(Point2f(400, 300)),
    center = PositionForce(target=Point2f(400, 300)),
    charge=ManyBodyForce(),
    )
  for _ in 1:initial_iterations
    step!(sim)
  end
  

  p = igraphplot!(ax, g, sim)    

  p[:node_pos][] = sim.positions
  
  taskref = Ref{Union{Nothing,Task}}(nothing)
  should_close = Ref(false)

  on(butr.clicks) do _
    sim.alpha.alpha = min(sim.alpha.alpha * 10, 1.0)
  end

  on(buta.clicks) do _
    if taskref[] === nothing
      taskref[] = @async begin
        while true
          sleep(1 / 30)

          step!(sim)
          p[:node_pos][] = sim.positions

          should_close[] && break
        end
        should_close[] = false
      end
    end
    Consume(true)
  end

  on(buts.clicks) do _
    if taskref[] !== nothing && !should_close[]
      should_close[] = true
      wait(taskref[])
      taskref[] = nothing
      #set_close_to!(sl, 0)
    end
    Consume(true)
  end
  f
end
