# resurfaceio-network-sniffer

Capture detailed API calls directly from network traffic to your own [data lake](https://resurface.io).

## Contents

- [Requirements](#requirements)
- [Capturing network traffic](#capturing-network-traffic)
- [Environment variables](#environment-variables)
- [VPC mirroring](#vpc-mirroring)
- [Protecting User Privacy](#protecting-user-privacy)

## Requirements

- docker
- Host network access, including `NET_ADMIN` and `NET_RAW` kernel capabilities.

## Capturing network traffic

Our `network-sniffer` runs as an independent containerized application. It captures packets from network interfaces, reassembles them, parses both HTTP request and response, packages the entire API calls, and sends it to your Resurface DB instance automatically.

We use [GoReplay](https://github.com/resurfaceio/goreplay) to capture HTTP traffic directly from network devices in userspace. Think `tcpdump` or Wireshark but without having to go through any of the packet reassembly or parsing process yourself.

After modifying the `.env` file with the required [environment variables](#environment-variables), just run the following docker command in the host machine:

```bash
docker run -d --name netsniffer --env-file .env --network host resurfaceio/network-sniffer:1.2.3
```

The `--network host` option must be specified in to capture traffic from other containers (or non-containerized apps) running in the machine.

### Example: Demo app with network-sniffer as sidecar

The `network-sniffer` container option works great when orchestrating different applications. In this example, we use `docker-compose` but you can also use [Kubernetes](https://resurface.io/docs#sniffer-daemonset), or any other orchestration tool.

- Run `dockercompose up` in your terminal
- Go to http://localhost:7700 and log in to your Resurface instance
- Perform a few API calls to the `httpbin` service
    ```bash
    curl http://localhost:80/json
    ```
- See the API calls flowing into the Resurface UI

To stop all containers:

```bash
docker compose down --remove-orphans
```

## Environment variables

All capture integrations by Resurface use two main environment variables:

- `USAGE_LOGGERS_URL` stores [the Resurface capture URL](https://resurface.io/docs#getting-capture-url), which by default should be
    ```
    http://localhost:7701/message
    ```
- `USAGE_LOGGERS_RULES` stores a set of rules used to filter sensitive info when logging API calls. [Learn more](#protecting-user-privacy)

The `network-sniffer` application uses two additional variables:

- `APP_PORTS` is a comma-separated list of integer values that correspond to the ports where your applications are being served in the host machine.
- `NET_DEVICE` corresponds to a specific network interface to capture packets from. When not set (or set to an empty string), the application captures from all available interfaces. You can get a list of all the available interfaces with the `ip a` (unix) or `ipconfig` (Windows) commands.

The `COMPOSE_PROFILES` environment variable sets the profile to use when no `--profle` option is passed when running `docker-compose -d up`

## VPC mirroring

Capturing inbound and outbound traffic from the network interfaces that are attached to EC2 instances can be achieved with VPC mirroring. Click [here](https://resurface.io/aws-vpc-mirroring) for a step-by-step guide on how to set that up using AWS.

Once you have created the traffic mirror session with its corresponding filter, the mirrored traffic is encapsulated in a VXLAN header. All VXLAN headers are associated with a 24-bit segment ID named VXLAN Network Identifier (VNI) for a given VPC mirroring session. The target EC2 instance will receive the mirrored traffic on the IANA-assigned port, UDP port 4789.

Then, add the following lines to your `.env` file:

```bash
RAW_ENGINE=vxlan
VXLAN_PORT=4789
```

and run the `network-sniffer` container:

```bash
docker run -d --name netsniffer --env-file .env --network host resurfaceio/network-sniffer:1.2.3
```

## Kubernetes

Please refer to the `sniffer` section in the `resurfaceio/resurface` chart's [README](https://github.com/resurfaceio/containers/blob/v3.5.x/helm/resurfaceio/resurface/README.md).

## Protecting User Privacy

Loggers always have an active set of <a href="https://resurface.io/logging-rules">rules</a> that control what data is logged
and how sensitive data is masked. All of the examples above apply a predefined set of rules (`include debug`),
but logging rules are easily customized to meet the needs of any application.

<a href="https://resurface.io/logging-rules">Logging rules documentation</a>

---
<small>&copy; 2016-2023 <a href="https://resurface.io">Resurface Labs Inc.</a></small>
