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

