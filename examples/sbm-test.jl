using Graphs, GLMakie, GraphPlayground, LinearAlgebra
function stochastic_block_model(blocks::Vector{Int}, p::Matrix{Float64})
  n = sum(blocks)
  g = SimpleGraph(n)
  
  start_indices = cumsum(vcat(1, blocks[1:end-1]))
  
  for i in 1:length(blocks)
    for j in i:length(blocks)
      for u in start_indices[i]:(start_indices[i] + blocks[i] - 1)
        for v in start_indices[j]:(start_indices[j] + blocks[j] - 1)
          if (i != j || u < v) && rand() < p[i, j]
            add_edge!(g, u, v)
          end
        end
      end
    end
  end
  
  return g
end

##

# Number of nodes in each block
blocks = [50, 50, 50, 50]

# Probability matrix
p = ones(length(blocks), length(blocks)) * 0.001
p .+= 0.1*Diagonal(ones(length(blocks)))

# Generate the SBM graph
g = stochastic_block_model(blocks, p)

playground(g) 