local resty_chash = require "resty.chash"

local loadbalancer = {}

loadbalancer.setup_server_list = function()
  local server_list = {
    ["edge"] = 1,
    ["edge1"] = 1,
    ["edge2"] = 1,
  }
  local chash_up = resty_chash:new(server_list)

  package.loaded.my_chash_up = chash_up
  package.loaded.my_servers = server_list
end

loadbalancer.set_proper_server = function()
  local b = require "ngx.balancer"
  local chash_up = package.loaded.my_chash_up
  local servers = package.loaded.my_ip_servers
  local id = chash_up:find(ngx.var.uri) -- hashing based on uri

  assert(b.set_current_peer(servers[id] .. ":8080"))
end

loadbalancer.resolve_name_for_upstream = function()
  local resolver = require "resty.dns.resolver"
  local r, err = resolver:new{
    nameservers = {"127.0.0.11", {"127.0.0.11", 53} },
    retrans = 5,
    timeout = 1000,
    no_random = true,
  }
  -- quick hack, we could use ips already
  -- or resolve names on background
  if package.loaded.my_ip_servers ~= nil then
    return
  end

  local servers = package.loaded.my_servers
  local ip_servers = {}

  for host, weight in pairs(servers) do
    local answers, err, tries = r:query(host, nil, {})
    ip_servers[host] = answers[1].address
  end

  package.loaded.my_ip_servers  = ip_servers
end

return loadbalancer
