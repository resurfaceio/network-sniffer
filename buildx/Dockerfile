FROM golang:alpine3.19 AS build
ARG GORVERSION
RUN apk add --no-cache --upgrade linux-headers build-base make git flex bison && wget http://www.tcpdump.org/release/libpcap-1.10.4.tar.gz && tar xzf libpcap-1.10.4.tar.gz && cd libpcap-1.10.4 && ./configure && make install
RUN git clone --depth 1 --branch $GORVERSION https://github.com/resurfaceio/goreplay.git && cd goreplay
WORKDIR /go/goreplay
ARG TARGETOS TARGETARCH
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /out/gor -ldflags "-extldflags=-static" ./cmd/gor/

FROM alpine:3.19
COPY --from=build /out/gor /bin
COPY ./scripts/*.sh /bin
ENTRYPOINT [ "sniffer.sh" ]
