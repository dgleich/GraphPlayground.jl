## Recording the examples in the README.md
using Graphs, GraphPlayground, GeometryBasics, GLMakie

##
g = smallgraph(:karate)
p = playground(g)

# Need to show the mousepointer 
mppos = Observable(Point2f(0,0))
xoffset = 0.1
poffset = -0.1
arrow_path = BezierPath([
    MoveTo(Point(0+xoffset, 0+poffset)),
    LineTo(Point(0.3+xoffset, -0.3+poffset)),
    LineTo(Point(0.15+xoffset, -0.3+poffset)),
    LineTo(Point(0.3+xoffset, -1+poffset)),
    LineTo(Point(0+xoffset, -0.9+poffset)),
    LineTo(Point(-0.3+xoffset, -1+poffset)),
    LineTo(Point(-0.15+xoffset, -0.3+poffset)),
    LineTo(Point(-0.3+xoffset, -0.3+poffset)),
    ClosePath()
])
scatter!(p.window.root_scene, mppos, markersize=25, 
  marker = arrow_path, rotation=pi/4, color=:grey,
  strokecolor=:white, strokewidth=2)
on(events(p.window.root_scene).mouseposition) do pos
  mppos[] = pos
end

##
record(p.window.root_scene, "karate.gif") do io
  while isopen(p.window)
    recordframe!(io)
  end
end 


##
using Graphs, GraphPlayground, GeometryBasics
g = grid([100,100]) # make a 100x100 grid from Graphs
p = playground(g, 
  ForceSimulation(Point2f, vertices(g); 
    link=LinkForce(;edges=edges(g), iterations=10, distance=0.5, strength=1),
    charge=ManyBodyForce(;strength=-1), 
    center=PositionForce(target=Point2f(300,300)));
  graphplot_options = (;node_size=[2 for _ in 1:nv(g)], edge_width=[1.0 for _ in 1:ne(g)]))
display(p)     
p.sim.alpha.alpha_target = 0.5 # keep the simulation hot for a while

# Need to show the mousepointer 
mppos = Observable(Point2f(0,0))
xoffset = 0.1
poffset = -0.1
arrow_path = BezierPath([
    MoveTo(Point(0+xoffset, 0+poffset)),
    LineTo(Point(0.3+xoffset, -0.3+poffset)),
    LineTo(Point(0.15+xoffset, -0.3+poffset)),
    LineTo(Point(0.3+xoffset, -1+poffset)),
    LineTo(Point(0+xoffset, -0.9+poffset)),
    LineTo(Point(-0.3+xoffset, -1+poffset)),
    LineTo(Point(-0.15+xoffset, -0.3+poffset)),
    LineTo(Point(-0.3+xoffset, -0.3+poffset)),
    ClosePath()
])
scatter!(p.window.root_scene, mppos, markersize=25, 
  marker = arrow_path, rotation=pi/4, color=:grey,
  strokecolor=:white, strokewidth=2)
on(events(p.window.root_scene).mouseposition) do pos
  mppos[] = pos
end

##
record(p.window.root_scene, "mesh.gif") do io
  while isopen(p.window)
    recordframe!(io)
  end
end 