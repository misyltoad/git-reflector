FROM alpine
RUN apk add --no-cache build-base sudo bsd-compat-headers automake m4 openssl openssl-dev luajit lua-dev luarocks5.1
RUN sudo -H luarocks-5.1 install http
RUN sudo -H luarocks-5.1 install sha1

RUN mkdir /reflector
ADD server.lua /reflector/

EXPOSE 80/tcp
WORKDIR /reflector
ENTRYPOINT ["luajit", "server.lua"]

