FROM igorbarinov/openresty-nginx-module-vts

RUN apk  --no-cache --virtual .build-deps add build-base git \
  && git clone https://github.com/openresty/lua-resty-balancer.git \
  && cd lua-resty-balancer/ \
  && make \
  && cp -r lib/resty/* /usr/local/openresty/lualib/resty/ \
  && cp librestychash.so /usr/local/openresty/lualib/ \
  && apk del .build-deps
