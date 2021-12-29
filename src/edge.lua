local simulations = require "simulations"
local edge = {}

edge.simulate_load = function()
  simulations.for_work_longtail(simulations.profiles.edge)
end

return edge
