function simpleforces(pts, vel2; 
  strength=-30.0, 
  min_distance2 = 1.0,
  max_distance2 = Inf,
  alpha=1.0)

  function _compute_force(pt1, pt2, strength)
    d = pt2 .- pt1
    d2 = GraphPlayground.dot(d, d) # use dot from GraphPlayground 
    if d2 < max_distance2
      #d = jiggle(d, rng)
      d2 = GraphPlayground.dot(d, d) # use dot from GraphPlayground 
      if d2 < min_distance2
        d2 = sqrt(min_distance2*d2)
      end

      w = strength*alpha / d2
      return d .* w 
    else
      return 0.0 .* pt1 
    end 
  end 

  for i in eachindex(pts)
    targetpt = pts[i]
    f = 0.0 .* targetpt 
    
    for j in eachindex(pts)
      if i != j
        f = f .+ _compute_force(targetpt, pts[j], strength)
      end 
    end
    vel2[i] = f
  end 
end


function approxforces(pts) 
  vel = 0 .* pts
  strengths = map(pt -> Float32(-30), pts)
  rng = StableRNG(1)
  theta2 = Float32(0.81)
  max_distance2 = Float32(Inf)
  min_distance2 = Float32(1.0)
  GraphPlayground.manybodyforce!(Float32(1.0), pts, pts, vel, strengths, min_distance2, max_distance2, theta2, rng)
end

function test_simpleforces(npts, approxfun, rtol; kwargs...)
  pts = rand(StableRNG(1), Point2f, npts)
  vel2 = approxfun(pts) 
  vel = similar(pts)
  simpleforces(pts, vel; kwargs...)
  return isapprox(vel, vel2; rtol=rtol)
end

@testset "simpleforces" begin
  @test test_simpleforces(100, approxforces, 1e-1)
  @test test_simpleforces(250, approxforces, 1e-1)
  @test test_simpleforces(500, approxforces, 1e-1)
end