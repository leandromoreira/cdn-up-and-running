local simulations = {}
local random = math.random
local sleep = ngx.sleep
local second = 0.001 -- a millisecond in second

-- setup entropy
math.randomseed(ngx.time() + ngx.worker.pid())

-- a percentile distribution based on a percentiles map
-- {
--  {
--    p=50, min=1, max=400,
--  }
-- }
-- for instance, for 50% we'll wait min 1ms and max 400ms
simulations.for_work_longtail = function(percentiles)
  -- sort by percentile
  table.sort(percentiles, function(a,b) return  a.p < b.p end)

  local current_percentage = random(1, 100)
  local min_wait_ms = 1
  local max_wait_ms = 1000

  for _, percentile in pairs(percentiles) do
    if current_percentage <= percentile.p then
      min_wait_ms = percentile.min
      max_wait_ms = percentile.max
      break
    end
  end

  local sleep_seconds = random(min_wait_ms, max_wait_ms) * second -- sleep expects seconds
  ngx.header["X-Latency"] = "simulated=" .. sleep_seconds .. "s, min=" .. min_wait_ms .. ", max=" .. max_wait_ms .. ", profile=" .. (ngx.var.arg_profile or "empty")

  sleep(sleep_seconds)
end

-- the percentile latency configuation in ms
simulations.profiles = {
  edge={
    {p=50, min=1, max=20,}, {p=90, min=21, max=50,}, {p=95, min=51, max=150,}, {p=99, min=151, max=500,},
  },
  backend={
    {p=50, min=100, max=400,}, {p=90, min=401, max=500,}, {p=95, min=501, max=1500,}, {p=99, min=1501, max=3000,},
  },
}

return simulations
