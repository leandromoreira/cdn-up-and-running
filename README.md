# CDN Up and Running (WIP)

The objective of this repo is to build a body of knowledge on how CDNs work by coding one from "scratch". The CDN we're going to architect uses: nginx, lua, docker, docker-compose, Prometheus, grafana, and wrk.

We'll start creating a single backend service and expand from there to a multi-node, latency simulated, observable, and testable CDN. In each section, there are discussions regarding the challenges and trade-offs of building/managing/operating a CDN.

![overview architecture](/img/initial_architecture.webp "overview architecture")
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
* Linux/GNU/Kernel - a kernel / operating system with outstanding networking capabilities as well as IO excellence.
* Nginx - an excellent web server that can be used as a reverse proxy providing caching ability.
* Lua - a simple powerful language to add features into nginx.
* Prometheus - A system with a dimensional data model, flexible query language, efficient time series database.
* Grafana - The open source analytics & monitoring
* Containers - technology to package, deploy, and isolate applications, we'll use docker and docker compose.

# Origin - the backend service

Origin is the system where the content is created. Or at least is the source of it to the CDN. The sample service we're going to build will be a straightforward JSON API. The backend service could be returning an image, a video, a javascript, an HTML page, a game, anything you want to deliver to your clients.

We'll use Nginx and Lua to design the backend service. It's a great excuse to introduce Nginx and Lua since we're going to use them a lot here.

> **Warning: the backend service could be written in any language you like.**

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

> **Warning: Although this single accept queue serving multiple workers is common, there are other models to [load balance the incoming requests](https://blog.cloudflare.com/the-sad-state-of-linux-socket-balancing/).**

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

The [`events`](http://nginx.org/en/docs/ngx_core_module.html#events) provides context for connection processing configurations while [`worker_connections`](http://nginx.org/en/docs/ngx_core_module.html#worker_connections) defines the maximum number of simultaneous connections that can be opened by a worker process.
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

The [`server`](http://nginx.org/en/docs/http/ngx_http_core_module.html#server) sets the root configuration for a server, aka where we're going to setup specific behavior to the server.

```nginx
server {}
```

Within the `server` we can set the [`listen`](http://nginx.org/en/docs/http/ngx_http_core_module.html#listen) directive controlling the address and/or the port on which the [server will accept requests](http://nginx.org/en/docs/http/request_processing.html).

```nginx
listen 8080;
````

In the server configuration, we can specify a route by using the [`location`](http://nginx.org/en/docs/http/ngx_http_core_module.html#location) directive. This will be used to provide specific configuration at the request path level.

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

Notice that most of the directives contain their scope, for instance, the `location` is only applicable within the `location` (recursively) and `server` context.

![directive restriction](/img/nginx_directive_restriction.webp "directive restriction")

> **Warning: we won't comment on each directive we add from now on, we'll only describe the most relevant for the section.**

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

And, if you want, make sure to check the returned header header.

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

The [`vhost_traffic_status_zone`](https://github.com/vozlt/nginx-module-vts#vhost_traffic_status_zone) sets a memory space required for the metrics. The  [`vhost_traffic_status_filter_by_set_key`](https://github.com/vozlt/nginx-module-vts#vhost_traffic_status_filter_by_set_key) groups metrics by a given variable (for instance, we decided to group metrics by `status`). And finally, the [`vhost_traffic_status_histogram_buckets`](https://github.com/vozlt/nginx-module-vts#vhost_traffic_status_histogram_buckets) provides a way to bucketize the metrics in seconds. We decided to create buckets varying from `0.005` to `10` seconds. These buckets will help us to visualize the metrics in histograms (`p99`, `p50`, etc).

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

With metrics, we can run (load) tests and see if the assumptions (configuration) matches with reality.

## Refactoring the nginx conf

As the configuration becomes bigger, it also gets harder to comprehend. Nginx offers a neat directive called [`include`](http://nginx.org/en/docs/ngx_core_module.html#include)that allows us to create partial config files and include them into the root configuration file.

```diff
-    location /status {
-      vhost_traffic_status_display;
-      vhost_traffic_status_display_format html;
-    }
+    include basic_vts_location.conf;

```

We can extract location, specific configurations, or anything that makes sense to a file. We can do a similar thing for the Lua code as well.

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
