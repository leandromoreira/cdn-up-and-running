local backend = {}

backend.generate_content = function()
  ngx.header['Content-Type'] = 'application/json'
  ngx.header['Cache-Control'] = 'public, max-age=' .. (ngx.var.arg_max_age or 10)

  ngx.say('{"service": "api", "value": 42, "request": "' .. ngx.var.uri .. '"}')
end

return backend
