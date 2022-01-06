# CDN Up and Running (WIP)

The objective of this repo is to build a body of knowledge on how CDNs work by coding one from "scratch". The CDN we're going to architect uses: nginx, lua, docker, docker-compose, Prometheus, grafana, and wrk.

We'll start creating a single backend service and expand from there to a multi-node, latency simulated, observable, and testable CDN. In each section, there are discussions regarding the challenges and trade-offs of building/managing/operating a CDN.

![grafana screenshot](/img/4.0.1_metrics.webp "grafana screenshot")

## What is a CDN?

A Content Delivery Network is a set of computers, spatially distributed, tasked to provide high availability, **better performance** for systems that can have their **work cached** on this network.

## Why do you need a CDN?

A CDN can help to improve:
* faster loading times (smoother streaming, instant page to buy, quick friends feed, etc)
* accommodate traffic spikes (black friday, popular streaming release, breaking news, etc)
* decrease costs (traffic offloading)
* scalability for millions

## How does a CDN work?

CDNs are able to make the services faster by placing the content (a media file, page, a game, javascript, a json response, etc) closer to the users.

When a user wants to consume a service, the CDN routing system will deliver the "best" node where the content is likely **already cached and closer to the client**. Don't worry about the loose use of the word best in here. I hope that throughout the reading, the understanding of what is the best node will be elucidated.

## The CDN stack

The CDN we'll build relies on:
* [`Linux/GNU/Kernel`](https://www.linux.org/) - a kernel / operating system with outstanding networking capabilities as well as IO excellence.
* [`Nginx`](http://nginx.org/) - an excellent web server that can be used as a reverse proxy providing caching ability.
* [`Lua(jit)`](https://luajit.org/) - a simple powerful language to add features into nginx.
* [`Prometheus`](https://prometheus.io/) - A system with a dimensional data model, flexible query language, efficient time series database.
* [`Grafana`](https://github.com/grafana/grafana) - The open source analytics & monitoring
* [`Containers`](https://www.docker.com/) - technology to package, deploy, and isolate applications, we'll use docker and docker compose.

# Origin - the backend service

Origin is the system where the content is created. Or at least is the source of it to the CDN. The sample service we're going to build will be a straightforward JSON API. The backend service could be returning an image, a video, a javascript, an HTML page, a game, anything you want to deliver to your clients.

We'll use Nginx and Lua to design the backend service. It's a great excuse to introduce Nginx and Lua since we're going to use them a lot here.

> **Heads up: the backend service could be written in any language you like.**

## Nginx - quick introduction

Nginx is a web server that will behave as you [configured it](http://nginx.org/en/docs/beginners_guide.html#conf_structure). Its configuration file uses [directives](http://nginx.org/en/docs/dirindex.html) as the dominant factor. A directive is a simple construction to set properties in nginx. There are two types of directives: simple and block (context).

A simple directive is formed by its name followed by parameters ending with a semicolon.

```nginx
# Syntax: <name> <parameters>;
# Example
add_header X-Header AnyValue;
```

The block directive follows the same pattern, but instead of a semicolon, it ends surrounded by braces. A block directive can also have directives within it. This block is also known as context.

```nginx
# Syntax: <name> <parameters> <block>
location / {
  add_header X-Header AnyValue;
}
```

Nginx uses workers (processes) to handle the requests. The [nginx architecture](https://www.aosabook.org/en/nginx.html) plays a crucial role in its performance.

![simplified workers nginx architecture](/img/simplified_workers_nginx_architecture.webp "simplified workers nginx architecture")

> **Heads up: Although this single accept queue serving multiple workers is common, there are other models to [load balance the incoming requests](https://blog.cloudflare.com/the-sad-state-of-linux-socket-balancing/).**

## Backend service conf

Let's walk through the backend JSON API nginx configuration. I think it'll be much easier to see it in action.

```nginx
events {
  worker_connections 1024;
}
error_log stderr;

http {
  access_log /dev/stdout;

  server {
    listen 8080;

    location / {
      content_by_lua_block {
        ngx.header['Content-Type'] = 'application/json'
        ngx.say('{"service": "api", "value": 42}')
      }
    }
  }
}
```

Were you able to understand what this config should do? In any case, let's break it down by commenting on each directive.

The [`events`](http://nginx.org/en/docs/ngx_core_module.html#events) provides context for [connection processing configurations](http://nginx.org/en/docs/events.html), and the [`worker_connections`](http://nginx.org/en/docs/ngx_core_module.html#worker_connections) defines the maximum number of simultaneous connections that can be opened by a worker process.
```nginx
events {
  worker_connections 1024;
}
```

The [`error_log`](http://nginx.org/en/docs/ngx_core_module.html#error_log) configures logging for error. Here we just send all the errors to the stdout (error)

```nginx
error_log stderr;
```

The [`http`](http://nginx.org/en/docs/http/ngx_http_core_module.html#http) provides a root context to set up all the http/s servers.

```nginx
http {}
```

The [`access_log`](http://nginx.org/en/docs/http/ngx_http_log_module.html#access_log) configures the path (and optionally format, etc) for the access logging.

```nginx
access_log /dev/stdout;
```

The [`server`](http://nginx.org/en/docs/http/ngx_http_core_module.html#server) sets the root configuration for a server, aka where we're going to setup specific behavior to the server. You can have multiple `server` blocks per `http` context.

```nginx
server {}
```

Within the `server` we can set the [`listen`](http://nginx.org/en/docs/http/ngx_http_core_module.html#listen) directive controlling the address and/or the port on which the [server will accept requests](http://nginx.org/en/docs/http/request_processing.html).

```nginx
listen 8080;
````

In the server configuration, we can specify a route by using the [`location`](http://nginx.org/en/docs/http/ngx_http_core_module.html#location) directive. This will be used to provide specific configuration for that matching request path.

```nginx
location / {}
```

Within this location (by the way, `/` will handle all the requests) we'll use Lua to create the response. There's a directive called [`content_by_lua_block`](https://github.com/openresty/lua-nginx-module#content_by_lua_block) which provides a context where the Lua code will run.

```nginx
content_by_lua_block {}
```

Finally, we'll use Lua and the basic [Nginx Lua API](https://github.com/openresty/lua-nginx-module#nginx-api-for-lua) to set the desired behavior.

```lua
-- ngx.header sets the current response header that is to be sent.
ngx.header['Content-Type'] = 'application/json'
-- ngx.say will write the response body
ngx.say('{"service": "api", "value": 42}')
```

Notice that most of the directives contain their scope. For instance, the `location` is only applicable within the `location` (recursively) and `server` context.

![directive restriction](/img/nginx_directive_restriction.webp "directive restriction")

> **Heads up: we won't comment on each directive we add from now on, we'll only describe the most relevant for the section.**

## CDN 1.0.0 Demo time

Let's see what we did.

```bash
git checkout 1.0.0 # going back to specific configuration
docker-compose run --rm --service-ports backend # run the containers exposing the service
http http://localhost:8080/path/to/my/content.ext # consuming the service, I used httpie but you can use curl or anything you like

# you should see the json response :)
```

## Adding caching capabilities

For the backend service to be cacheable we need to set up the caching policy. We'll use the HTTP header [Cache-Control](https://developer.mozilla.org/en-US/docs/Web/HTTP/Headers/Cache-Control) to setup what caching behavior we want.

```Lua
-- we want the content to be cached by 10 seconds OR the provided max_age (ex: /path/to/service?max_age=40 for 40 seconds)
ngx.header['Cache-Control'] = 'public, max-age=' .. (ngx.var.arg_max_age or 10)
```

And, if you want, make sure to check the returned response header `Cache-Control`.

```bash
git checkout 1.0.1 # going back to specific configuration
docker-compose run --rm --service-ports backend
http "http://localhost:8080/path/to/my/content.ext?max_age=30"
```

## Adding metrics

Checking the logging is fine for debugging. But once we're reaching more traffic, it'll be near impossible to understand how the service is operating. To tackle this, we're going to use [VTS](https://github.com/vozlt/nginx-module-vts), and nginx module that adds metrics measurements.

```nginx
vhost_traffic_status_zone shared:vhost_traffic_status:12m;
vhost_traffic_status_filter_by_set_key $status status::*;
vhost_traffic_status_histogram_buckets 0.005 0.01 0.05 0.1 0.5 1 5 10; # buckets are in seconds
```

The [`vhost_traffic_status_zone`](https://github.com/vozlt/nginx-module-vts#vhost_traffic_status_zone) sets a memory space required for the metrics. The  [`vhost_traffic_status_filter_by_set_key`](https://github.com/vozlt/nginx-module-vts#vhost_traffic_status_filter_by_set_key) groups metrics by a given variable (for instance, we decided to group metrics by `status`). And finally, the [`vhost_traffic_status_histogram_buckets`](https://github.com/vozlt/nginx-module-vts#vhost_traffic_status_histogram_buckets) provides a way to bucketize the metrics in seconds. We decided to create buckets varying from `0.005` to `10` seconds. These buckets will help us to create percentiles (`p99`, `p50`, etc).

```nginx
location /status {
  vhost_traffic_status_display;
  vhost_traffic_status_display_format html;
}
```

We also must expose the metrics in a location, we decided to use the `/status` to do it. Demo time, if you want to.

```bash
git checkout 1.1.0
docker-compose run --rm --service-ports backend
# if you go to http://localhost:8080/status/format/html you'll see information about the server 8080
# notice that VTS also provides other formats such as status/format/prometheus, which will be pretty helpful for us in near future
```

![nginx vts status page](/img/metrics_status.webp "nginx vts status page")

With metrics, we can run (load) tests and see if the assumptions (configuration) matches with reality.

## Refactoring the nginx conf

As the configuration becomes bigger, it also gets harder to comprehend. Nginx offers a neat directive called [`include`](http://nginx.org/en/docs/ngx_core_module.html#include) which allows us to create partial config files and include them into the root configuration file.

```diff
-    location /status {
-      vhost_traffic_status_display;
-      vhost_traffic_status_display_format html;
-    }
+    include basic_vts_location.conf;

```

We can extract location, group configurations per similarities, or anything that makes sense to a file. We can do [a similar thing for the Lua code](https://github.com/openresty/lua-nginx-module#lua_package_path) as well.

```diff
       content_by_lua_block {
-        ngx.header['Content-Type'] = 'application/json'
-        ngx.header['Cache-Control'] = 'public, max-age=' .. (ngx.var.arg_max_age or 10)
-
-        ngx.say('{"service": "api", "value": 42, "request": "' .. ngx.var.uri .. '"}')
+        local backend = require "backend"
+        backend.generate_content()
       }
```

All these modifications were made to improve readability, it also promotes reuse.


# The CDN - siting in front of the backend

## Proxying

What we did up to this point has nothing to do with the CDN. Now it's time to start building the CDN. For that matter, we'll create another node with nginx, just adding some new directives to connect the `edge` (CDN) node with the `backend` node.

![backend edge architecture](/img/edge_backend.webp "backend edge architecture")

There's really nothing fancy, just an [`upstream`](http://nginx.org/en/docs/http/ngx_http_upstream_module.html#upstream) block with a server pointing to our `backend` endpoint. In the location, we do not provide the content instead, we just say that the content is hosted at the [`proxy_pass`](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass) and link it to the upstream we just created.

```nginx
upstream backend {
  server backend:8080;
  keepalive 10;  # connection pool for reuse
}

server {
  listen 8080;

  location / {
    proxy_pass http://backend;
    add_header X-Cache-Status $upstream_cache_status;
  }
}
````

We also added a new header (X-Cache-Status) to indicate whether the cache was used or not.
* **HIT**: when the content is in the CDN, the `X-Cache-Status` should return a hit.
* **MISS**: when the content isn't in the CDN, the `X-Cache-Status` should return a miss.

```bash
git checkout 2.0.0
docker-compose up
# we still can fetch the content from the backend
http "http://localhost:8080/path/to/my/content.ext"
# but we really want to access the content through the edge (CDN)
http "http://localhost:8081/path/to/my/content.ext"
```

## Caching

When we try to fetch content, the `X-Cache-Status` header never shows up. It seems that the edge node always making an extra request. We hit the edge, and it invariably tries to fetch the content from the backend, not the way a CDN should work, right?

```log
backend_1     | 172.22.0.4 - - [05/Jan/2022:17:24:48 +0000] "GET /path/to/my/content.ext HTTP/1.0" 200 70 "-" "HTTPie/2.6.0"
edge_1        | 172.22.0.1 - - [05/Jan/2022:17:24:48 +0000] "GET /path/to/my/content.ext HTTP/1.1" 200 70 "-" "HTTPie/2.6.0"
````

The edge is just proxying the clients to the backend. What are we missing? Is there any reason to use a "simple" proxy at all? Well, it does, maybe you want to provide throttling, authentication, authorization, tls termination, or a gateway for multiple services, but that's not what we want.

We need to create a cache area on nginx through the directive [`proxy_cache_path`](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_path). It's setting up the path where the cached content will reside, the shared memory `key_zone`, and policies such as `inactive`, `max_size`, among others, to control how we want the cache to behave.

```nginx
proxy_cache_path /cache/ levels=2:2 keys_zone=zone_1:10m max_size=10m inactive=10m use_temp_path=off;
```

Once we've configured a proper cache, we must also set up the [`proxy_cache`](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache) pointing to the right zone (via `proxy_cache_path keys_zone=<name>:size`), and the [`proxy_pass`](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_pass) linking to the upstream we've created.

```nginx
location / {
    # ...
    proxy_pass http://backend;
    proxy_cache zone_1;
}
```

There is another important aspect of caching which is managed by the directive [`proxy_cache_key`](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_key).
When a client requests content from nginx, it will (highly simplified):

* Receive the request (let's say: `GET /path/to/something.txt`)
* Apply a hash md5 function over the cache key value (let's assume that the cache key is the `uri`)
  * md5("/path/to/something.txt") => `b3c4c5e7dc10b13dc2e3f852e52afcf3`
    * you can check that on your terminarl `echo -n "/path/to/something.txt" | md5`
* It checks whether the content (hash `b3c4..`) is cached or not
* If it's cached, it just returns the object otherwise it fetches the content from the backend

Let's create a variable called `cache_key` using the lua directive [`set_by_lua_block`](https://github.com/openresty/lua-nginx-module#set_by_lua), this will, for each incoming request, fill the `cache_key` with the `uri` value. Beyond that, we also need to update the [`proxy_cache_key`](http://nginx.org/en/docs/http/ngx_http_proxy_module.html#proxy_cache_key).

```nginx
location / {
    set_by_lua_block $cache_key {
      return ngx.var.uri
    }
    # ...
    proxy_cache_key $cache_key;
}
```

> **Heads up**: Using `uri` as cache key will make the following two requests http://example.a.com/path/to/content.ext and http://example.b.com/path/to/content.ext (if they're using the same cache proxy) as if they were a single object. If you do not provide a cache key, nginx will use a reasonable **default value** `$scheme$proxy_host$request_uri`.

Now we can see the caching properly working.

```bash
git checkout 2.1.0
docker-compose up
http "http://localhost:8081/path/to/my/content.ext"
# the second request must get the content from the CDN without leaving to the backend
http "http://localhost:8081/path/to/my/content.ext"
```

![cache hit header](/img/cache_hit.webp "cache hit header")

## Monitoring Tools

Checking the cache effectiveness by looking at the command line isn't efficient. It's better if we use a tool for that. **Prometheus** will be used to scrap the metrics on all servers, and **Grafana** will show graphics based on the metrics collected by the prometheus.

![instrumentalization architecture](/img/metrics_architecture.webp "instrumentalization architecture")

Prometheus configuration will look like this.

```yaml
global:
  scrape_interval:     10s # each 10s prometheus will scrap targets
  evaluation_interval: 10s
  scrape_timeout: 2s

  external_labels:
      monitor: 'CDN'

scrape_configs:
  - job_name: 'prometheus'
    metrics_path: '/status/format/prometheus'
    static_configs:
      - targets: ['edge:8080', 'backend:8080'] # the server list to be scrapped by the scrap_path
```

Now, we need to add a prometheus source for Grafana.

![grafana source](/img/add_source.webp "grafana source")

And set the proper prometheus server.

![grafana source set](/img/set_source.webp "grafana source set")

## Simulated Work (latency)

The backend server is artificially creating responses, we'll add simulated latency using lua. The ideia is to make it closer to real world situations. We're going to model the latency using [percentiles](https://www.mathsisfun.com/data/percentiles.html).

```lua
percentile_config={
    {p=50, min=1, max=20,}, {p=90, min=21, max=50,}, {p=95, min=51, max=150,}, {p=99, min=151, max=500,},
}
```

We randomly pick a number from 1 to 100, and then we apply another random using the `percentile profile` ranging from the min to the max. Finally we [`sleep`](https://github.com/openresty/lua-nginx-module#ngxsleep) that duration.

```lua
local current_percentage = random(1, 100)
-- let's assume we picked 94
local sleep_duration = random(percentile_profile.min, percentile_profile.max)
sleep(sleep_seconds)
```

This model let's us freely try to emulate closer to [real world observed latencies](https://research.google/pubs/pub40801/).

## Load Testing

We'll run some load testing to learn more about the solution we're building. Wrk is an HTTP benchmarking tool that you can dynamically configure using lua (again:P). We just pick an random number from 1 to 100 and make a request for that item.

```lua
request = function()
  local item = "item_" .. random(1, 100)

  return wrk.format(nil, "/" .. item .. ".ext")
end
```

The command line will run the tests for 10 minutes (600s), using two threads, and 10 connections.

```bash
wrk -c10 -t2 -d600s -s ./src/load_tests.lua --latency http://localhost:8081
```

Of course, you can run this on your machine:

```bash
docker-compose up

# run the tests
./load_test.sh

# go check on grafana, how the system is behaving
http://localhost:9091
```

The `wrk` output was as shown bellow. There were **37k** requests with **674** failing requests in total.

```bash
Running 10m test @ http://localhost:8081
  2 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   218.31ms  236.55ms   1.99s    84.32%
    Req/Sec    35.14     29.02   202.00     79.15%
  Latency Distribution
     50%  162.73ms
     75%  350.33ms
     90%  519.56ms
     99%    1.02s
  37689 requests in 10.00m, 15.50MB read
  Non-2xx or 3xx responses: 674
Requests/sec:     62.80
Transfer/sec:     26.44KB
```

Grafana showed that in a given instant **68** request/s were responded by the `edge`. From these requests, **16** went through the `backend`. The [cache effeciency](https://www.cloudflare.com/learning/cdn/what-is-a-cache-hit-ratio/) was **76%**, and 1% of the requests latency was bigger than **3.6s**, 5% observed more than **786ms**, and the median was around **73ms**.

![grafana result for 2.2.0](/img/2.2.0_metrics.webp "grafana result for 2.2.0")

## Learning by testing - let's change the cache ttl (max age)

This project should engage you to experiment, change parmeters values, run load testing, and check the results. I think this can be a great loop to learn by testing. Let's try to see what happens when we change the cache behavior.

### 1s

Using 1s for cache validity.

```lua
request = function()
  local item = "item_" .. random(1, 100)

  return wrk.format(nil, "/" .. item .. ".ext?max_age=1")
end
```

And run the tests, and the result is: only 16k requests with 773 errors.

```
Running 10m test @ http://localhost:8081
  2 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   378.72ms  254.21ms   1.46s    68.40%
    Req/Sec    15.11      9.98    90.00     74.18%
  Latency Distribution
     50%  396.15ms
     75%  507.22ms
     90%  664.18ms
     99%    1.05s
  16643 requests in 10.00m, 6.83MB read
  Non-2xx or 3xx responses: 773
Requests/sec:     27.74
Transfer/sec:     11.66KB
```

We also noticed that the cache hit went down signficantly `(23%)`, and many more requests leaked to the backend.

![grafana result for 2.2.1 1 second](/img/2.2.1_metrics_1s.webp "grafana result for 2.2.1 1 second")

### 60s

What if instead we increase the caching expire to a whole minute?!

```lua
request = function()
  local item = "item_" .. random(1, 100)

  return wrk.format(nil, "/" .. item .. ".ext?max_age=60")
end
```

Again, we run the tests, and the result now is: 45k requests with 551 errors.

```bash
Running 10m test @ http://localhost:8081
  2 threads and 10 connections
  Thread Stats   Avg      Stdev     Max   +/- Stdev
    Latency   196.27ms  223.43ms   1.79s    84.74%
    Req/Sec    42.31     34.80   242.00     78.01%
  Latency Distribution
     50%   79.67ms
     75%  321.06ms
     90%  494.41ms
     99%    1.01s
  45695 requests in 10.00m, 18.79MB read
  Non-2xx or 3xx responses: 551
Requests/sec:     76.15
Transfer/sec:     32.06KB
```

Now, we see a much better cache efficiency.

![grafana result for 2.2.1 60 seconds](/img/2.2.1_metrics_60s.webp "grafana result for 2.2.1 60 seconds")

> **Heads up**: caching for longer help to improve performance but at the cost of keeping an old content.

## Fine tunning - cache lock, stale, timeout, network
