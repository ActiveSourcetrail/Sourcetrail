# syntax=docker/dockerfile:1
# escape=`

# ----------------------------------------------------------------------------
FROM golang:1.20-alpine as builder

SHELL ["/bin/sh", "-c"]

WORKDIR /app

ADD `
    https://github.com/lesomnus/vcpkg-cache-http/archive/refs/heads/main.zip `
    main.zip

RUN `
    # build
    unzip main.zip && `
    cd vcpkg-cache-http-main && `
    go build -o vcpkg-cache-http && `
    cp vcpkg-cache-http ../vcpkg-cache-http && `
    cd .. && `
    rm -rf vcpkg-cache-http-main 

VOLUME ["/app/vcpkg-cache"]

EXPOSE 15151/tcp

ENTRYPOINT ["/app/vcpkg-cache-http"]
