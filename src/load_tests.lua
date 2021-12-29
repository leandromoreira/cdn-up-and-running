math.randomseed(os.time())
local random = math.random

local popular_percentage = 96
local popular_items_quantity = 5
local max_total_items = 200

-- trying to model the long tail
request = function()
  local is_popular = random(1, 100) <= popular_percentage
  local item = ""

  if is_popular then
    item = "item-" .. random(1, popular_items_quantity)
  else
    item = "item-" .. random(popular_items_quantity + 1, popular_items_quantity + max_total_items)
  end

  return wrk.format(nil, "/path/" .. item .. ".ext")
end

