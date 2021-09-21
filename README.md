# goreplay-dockerized
Log detailed API calls from network traffic with GoReplay to your own [system of record](https://resurface.io).

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
Resurface uses [GoReplay](https://goreplay.org/) to log HTTP traffic from the network. We offer different alternatives to accomplish this:
- [All-in-one container](#all-in-one-container) (Linux only)
- [Sidecar container](#sidecar-container) (Linux only)
- [Run GoReplay directly on your host machine](#direct-approach-option)

### All-in-one container
GoReplay runs alongside Resurface in the same container. This option works great for demos, dev environments, and single-node solutions but it might not provide the flexibility needed in a production environment.

#### Building the image
- Clone this repo
- `cd` into the directory where you cloned it
- Run `docker build -t resurface:gor .`

#### Running the container
- Build the image
- Run `docker run -d --name resurface-gor --network host resurface:gor`

#### Working with the network sniffer
The GoReplay application does not autostart by default. Instead you can start and stop it when you need it, like this:
- **Start**: `docker exec resurface-gor sniffer on`
- **Stop**: `docker exec resurface-gor sniffer off`
- **Status**: `docker exec resurface-gor sniffer`

### Sidecar container
GoReplay runs as an independent containerized application. This option works great when orchestrating different containerized applications. In this example, we use `docker-compose` but you can use any other orchestration tool.

#### Building the image
- Clone this repo
- `cd` into the directory where you cloned it
- Run `docker build -t goreplay:resurface -f Dockerfile.sidecar .`

#### Running the containers
- Build the image
- Modify the `.env` file with the required [environment variables](#environment-variables) accordingly.
- Run `docker-compose up`

### Direct approach option
This option allows you to run the GoReplay binary directly on your host machine. Choose this option if your host machine isn't running Linux.

#### Install npcap (Windows only)
By default, Windows doesn't support packet capture like Unix systems do. In order to perform this operation, a packet capture library like [npcap](https://nmap.org/npcap/) must be installed first.

#### Download the network sniffer application
- Download the tarball or binary file that corresponds to you system from the [bin directory](https://github.com/resurfaceio/goreplay/tree/master/bin).
- Extract or install accordingly.

#### Running the network sniffer application
- Local network: Run `gor --input-raw $APP_PORT --input-track-response --output-resurface $USAGE_LOGGERS_URL --output-resurface-rules $USAGE_LOGGER_RULES`
- VPC Mirroring: Run `gor --input-raw $VPC_MIRROR_DEVICE:$APP_PORT --input-raw-track-response --input-raw-bpf-filter "(dst port $APP_PORT) or (src port $APP_PORT)" --output-resurface $USAGE_LOGGERS_URL --output-resurface-rules $USAGE_LOGGER_RULES`

## Environment variables

Resurface uses two main environment variables:

- `USAGE_LOGGERS_URL` stores the Resurface database URL, which by default should be `http://localhost:4001/message`
- `USAGE_LOGGERS_RULES` stores a set of rules used to filter sensitive info when logging API calls. [Learn more](#protecting-user-privacy)

In addition, the `APP_PORT` environment variable tells the network sniffer where to listen in the host machine.

## VPC mirroring

Capturing inbound and outbound traffic from the network interfaces that are attached to EC2 instances can be achieved with VPC mirroring. Click [here](http://resurface.io/404) for a step-by-step guide on how to set that up using AWS.

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
<small>&copy; 2016-2021 <a href="https://resurface.io">Resurface Labs Inc.</a></small>
