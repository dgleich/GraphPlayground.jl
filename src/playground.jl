
function igraphplot!(ax, g; kwargs...)
  p = graphplot!(ax, g, sim, edge_width = [2.0 for i in 1:ne(g)],
              edge_color = [colorant"gray" for i in 1:ne(g)],
              node_size = [10 for i in 1:nv(g)],
              node_color = [colorant"black" for i in 1:nv(g)], 
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
    p[:node_pos][][idx] = event.data
    p[:node_pos][] = p[:node_pos][]

  end
  ndrag = NodeDragHandler(node_drag_action)
  register_interaction!(ax, :ndrag, ndrag)

  return p
end 

function plot_graph_with_buttons(g)
  f = Figure()
  ax = Axis(f[1, 1])
  ax.limits = (0, 640, 0, 480)
  
  buta = Button(f[2, :], label="Animate", tellwidth=false)
  buts = Button(f[3, :], label="Stop", tellwidth=false)
  #sl = Slider(f[4, :], range=range(0, 2 * pi, 50))
  
  p = igraphplot!(ax, g)

  sim = ForceSimulation(Point2f, vertices(g); 
    link=LinkForce(edges(g)), 
    center=CenterForce(Point2f(320, 240)),
    charge=ManyBodyForce(),
    )

  p[:node_pos][] = sim.positions
  
  taskref = Ref{Union{Nothing,Task}}(nothing)
  should_close = Ref(false)

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
