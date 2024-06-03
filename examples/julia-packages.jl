 using TOML
using Printf

# this variable needs to be changed based on your own installation directory
path = joinpath(homedir(),".julia","registries","General")
packages_dict = TOML.parsefile(joinpath(path,"Registry.toml"))["packages"]
# Get the root stdlib directory
function _get_stdlib_dir()
  ladir = Base.find_package("LinearAlgebra")
  # go up two directories from ladir
  return dirname(dirname(dirname(ladir)))
end 
const STDLIB_DIR = _get_stdlib_dir() 
const STDLIBS = readdir(STDLIB_DIR)

##
for (i, stdlib) in enumerate(STDLIBS)
    if isfile(joinpath(STDLIB_DIR, stdlib, "Project.toml"))
        proj = TOML.parsefile(joinpath(STDLIB_DIR, stdlib, "Project.toml"))
        packages_dict[proj["uuid"]] = proj
    end
end
pkg_keys = collect(keys(packages_dict))
pkg_ids = Dict(pkg_keys[i] => i-1 for i = 1:length(pkg_keys))

G = DiGraph(length(pkg_keys))
for i in eachindex(pkg_keys)
  pkg_id = pkg_ids[pkg_keys[i]]
  if haskey(packages_dict[pkg_keys[i]],"path")
    dep_path = joinpath(path,packages_dict[pkg_keys[i]]["path"],"Deps.toml")
    if isfile(dep_path)
        dep_dict = TOML.parsefile(dep_path)
        for key in keys(dep_dict)
            tmp_dict = dep_dict[key]
            for pkg_name in keys(tmp_dict)
                add_edge!(G, pkg_id, pkg_ids[tmp_dict[pkg_name]])
            end
        end
      end
    else
        if haskey(packages_dict[pkg_keys[i]],"deps")
            for key in packages_dict[pkg_keys[i]]["deps"]
                add_edge!(G, pkg_ids[key[2]], pkg_id)
            end
        end
    end
end
##
pkg_names = [packages_dict[pkg_keys[i]]["name"] for i = 1:length(pkg_keys)]
##
#playground(G)
playground(G,
  graphplot_options = (; node_size=outdegree(G).+1, 
    node_color = [colorant"red" for i in 1:nv(G)],
    edge_width = [1.0 for i in 1:ne(G)]),
  manybody_options = (; distance=-(outdegree(G) .+ 10)),
  link_options = (; distance=30, iterations=1),
  charge_options = (; strength=-30.0 .* outdegree(G) )
)


##
sim = ForceSimulation(Point2f, vertices(g); 
  link=LinkForce(edges=edges(g), iterations=10, distance=20, strength=1), charge=ManyBodyForce(), 
  center=GraphPlayground.CenterForce(Point2f(320, 240)))
for _ in 1:100  
  step!(sim)
end 
fig = Figure()
ax = Axis(fig[1,1])
GraphPlayground.igraphplot!(ax, g, sim; node_size=[10 for _ in 1:nv(g)])
fig