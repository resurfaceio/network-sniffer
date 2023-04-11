FROM golang:alpine3.17 AS build
RUN apk add --no-cache --upgrade linux-headers build-base make git flex bison && wget http://www.tcpdump.org/release/libpcap-1.10.3.tar.gz && tar xzf libpcap-1.10.3.tar.gz && cd libpcap-1.10.3 && ./configure && make install
RUN git clone https://github.com/resurfaceio/goreplay.git && cd goreplay && git checkout resurface
WORKDIR /go/goreplay
ARG TARGETOS TARGETARCH GORVER
RUN GOOS=$TARGETOS GOARCH=$TARGETARCH go build -o /out/gor -ldflags "-extldflags=-static -X main.VERSION=$GORVER" .

FROM alpine:3.17
COPY --from=build /out/gor /bin
COPY ./scripts/*.sh /bin
ENTRYPOINT [ "sniffer.sh" ]
