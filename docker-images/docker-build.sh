#!/bin/sh

docker buildx build --pull \
    --platform linux/arm64,linux/amd64 \
    --tag docker.flame.org/library/simh-vax:latest \
    --target release \
    --push .
