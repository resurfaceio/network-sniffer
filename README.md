# resurfaceio-network-sniffer

Capture detailed API calls from network traffic to your own [system of record](https://resurface.io).

## Contents

- [Requirements](#requirements)
- [Capturing network traffic](#capturing-network-traffic)
- [Environment variables](#environment-variables)
- [VPC mirroring](#vpc-mirroring)
- [Protecting User Privacy](#protecting-user-privacy)

## Requirements

- docker
- [Resurface](https://resurface.io/installation) (free docker container)

## Capturing network traffic

Resurface uses [GoReplay](https://github.com/resurfaceio/goreplay) to capture HTTP traffic directly from network devices in userspace. Think `tcpdump` or Wireshark but without having to go through any of the packet reassembly or parsing process yourself.

We offer two main alternatives for running the sniffer:
- [Sidecar container](#sidecar-container) (Linux only)
- [Run binary directly on your host machine](#direct-approach-option)

### Sidecar container

The `network-sniffer` application runs as an independent containerized application. This option works great when orchestrating different containerized applications. In this example, we use `docker-compose` but you can also use [Kubernetes](https://resurface.io/docs#sniffer-daemonset), or any other orchestration tool.

#### Building the image

- Clone this repo
- `cd` into the directory where you cloned it
- Run `docker build -t network-sniffer .`

#### Running the containers

- Build the image
- Modify the `.env` file with the required [environment variables](#environment-variables) accordingly.
- Run `docker-compose up`

### Direct approach option

This option allows you to run the binary directly on your host machine. Choose this option if your host machine isn't running Linux.

#### Install npcap (Windows only)

By default, Windows doesn't support packet capture like Unix systems do. In order to perform this operation, a packet capture library like [npcap](https://nmap.org/npcap/) must be installed first.

#### Download the network sniffer application

- Download the tarball or binary file that corresponds to you system from the [bin directory](https://github.com/resurfaceio/goreplay/tree/master/bin)

    Linux
    ```bash
    wget https://github.com/resurfaceio/goreplay/tree/master/bin/gor-resurface_x64.tar.gz
    ```
    macOS
    ```bash
    wget https://github.com/resurfaceio/goreplay/tree/master/bin/gor-resurface_mac.tar.gz
    ```
    Windows
    ```bash
    wget https://github.com/resurfaceio/goreplay/tree/master/bin/gor-resurface_windows.zip
    ```
- Extract the `gor` binary
    ```bash
    tar -xzf gor-resurface_x64.tar.gz  # linux
    ```
    ```bash
    tar -xzf gor-resurface_mac.tar.gz  # macOS
    ```
    ```bash
    Expand-Archive gor-resurface_windows.zip  # Windows
    ```
- Modify permissions if necessary
    ```bash
    chmod +x ./gor
    ```

#### Running the network sniffer application

- Set all the required [environment variables](#environment-variables) accordingly.
- Run the following command

    ```bash
    ./gor --input-raw $NET_DEVICE:$APP_PORTS --input-raw-track-response --input-raw-bpf-filter "(dst port $APP_PORT) or (src port $APP_PORT)" --output-resurface $USAGE_LOGGERS_URL --output-resurface-rules $USAGE_LOGGER_RULES
    ```

## Environment variables

All capture integrations by Resurface use two main environment variables:

- `USAGE_LOGGERS_URL` stores [the Resurface capture URL](https://resurface.io/docs#getting-capture-url), which by default should be `http://localhost:7701/message`
- `USAGE_LOGGERS_RULES` stores a set of rules used to filter sensitive info when logging API calls. [Learn more](#protecting-user-privacy)

The `network sniffer` application uses two additional variables:

- `APP_PORTS` is a comma-separated list of integer values that correspond to the ports where your applications are being served in the host machine.
- `NET_DEVICE` corresponds to a specific network interface to capture packets from. You can get a list of all the available interfaces with the `ip a ` command. When not set, the application captures from all available interfaces.

## VPC mirroring

Capturing inbound and outbound traffic from the network interfaces that are attached to EC2 instances can be achieved with VPC mirroring. Click [here](http://resurface.io/blog/api-calls-with-aws-vpc-mirroring) for a step-by-step guide on how to set that up using AWS.

Once you have created the traffic mirror session with its corresponding filter, the mirrored traffic is encapsulated in a VXLAN header. We can set up a new VXLAN interface on top of an existing `eth0` for tunnel endpoint communication using the following command:

    sudo ip link add vx0 type vxlan id $VNI local $SOURCE_EC2_IP remote $TARGET_EC2_IP dev eth0 dstport 4789

Here we are adding a virtual link named `vx0` that will work as a VXLAN interface on top of the `eth0` device. All VXLAN headers are associated with a 24-bit segment ID named VXLAN Network Identifier (VNI) for a given VPC mirroring session. The target EC2 instance will receive the mirrored traffic on the IANA-assigned port, UDP port 4789.

Then, just change the state of the device to UP:

    sudo ip link set vx0 up

Finally, set the environment variable `VPC_MIRROR_DEVICE=vx0` and  run the sniffer application using your favorite alternative.

## Protecting User Privacy

Loggers always have an active set of <a href="https://resurface.io/logging-rules">rules</a> that control what data is logged
and how sensitive data is masked. All of the examples above apply a predefined set of rules (`include debug`),
but logging rules are easily customized to meet the needs of any application.

<a href="https://resurface.io/logging-rules">Logging rules documentation</a>

---
<small>&copy; 2016-2022 <a href="https://resurface.io">Resurface Labs Inc.</a></small>
