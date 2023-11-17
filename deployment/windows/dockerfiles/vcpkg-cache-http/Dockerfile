# syntax=docker/dockerfile:1
# escape=`

# ----------------------------------------------------------------------------
FROM golang:1.20.10-nanoserver-1809 as builder

SHELL ["cmd", "/S", "/C"]

WORKDIR c:/app

ADD `
    https://github.com/lesomnus/vcpkg-cache-http/archive/refs/heads/main.zip `
    main.zip

RUN `
    # ping need time to bootstrap
    ping 127.0.0.1 -n 10 > nul && `
    `
    # build
    tar -xf main.zip && `
    cd vcpkg-cache-http-main && `
    go build -o vcpkg-cache-http && `
    copy vcpkg-cache-http ../vcpkg-cache-http && `
    cd .. && `
    rmdir /s /q vcpkg-cache-http-main 

VOLUME ["c:/app/vcpkg-cache"]

EXPOSE 15151/tcp

ENTRYPOINT ["c:/app/vcpkg-cache-http"]
