# run example codes
@testset "Examples" begin 
  @testset "README.md" begin
    using Graphs, GraphPlayground, GeometryBasics, GLMakie
    @testset "playground" begin
      g = smallgraph(:karate)
      p = playground(g)    
      display(p.sim)
      GLMakie.closeall()
    end

    
    p = playground(g; 
      link_options=(;distance=25), 
      charge_options=(;strength=-100))
    GLMakie.closeall()
      
    g = grid([100,100]) # make a 20x20 grid from Graphs
    p = playground(g, 
      ForceSimulation(Point2f, vertices(g); 
        link=LinkForce(;edges=edges(g), iterations=10, distance=0.5, strength=1),
        charge=ManyBodyForce(;strength=-1), 
        center=PositionForce(target=Point2f(300,300)));
      graphplot_options = (;node_size=[2 for _ in 1:nv(g)], edge_width=[1.0 for _ in 1:ne(g)]))
    display(p)     
    p.sim.alpha.alpha_target = 0.5 # keep the simulation hot for a while
    GLMakie.closeall()
  end 

  @testset "examples" begin 
    @testset "sbm-test" begin
      include("../examples/sbm-test.jl")
      GLMakie.closeall()
    end
    @testset "mouse-pointer-collision" begin
      include("../examples/mouse-pointer-collision.jl")
      GLMakie.closeall()
    end
  end
end 