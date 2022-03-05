FROM alpine:3 AS build

RUN apk update && \
    apk add git make sdl2-dev sdl2_ttf-dev gcc musl-dev libpcap-dev pcre-dev
RUN git clone --depth 1 --single-branch git://github.com/simh/simh.git
WORKDIR /simh
RUN make vax vax8600

FROM alpine:3 AS release

RUN apk add --no-cache pcre sdl2 libpng libpcap-dev

COPY --from=build /simh/BIN /simh/BIN
ADD run.sh /run.sh
WORKDIR /
CMD ["/bin/sh", "/run.sh"]
