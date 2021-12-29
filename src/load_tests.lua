math.randomseed(os.time())
local random = math.random

request = function()
  local item = "item_" .. random(1, 100)

  return wrk.format(nil, "/" .. item .. ".ext")
end

