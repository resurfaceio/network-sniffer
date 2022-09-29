## All-in-one container

GoReplay runs alongside Resurface in the same container. This option works great for demos, dev environments, and single-node solutions but it might not provide the flexibility needed in a production environment.

#### Building the image
- Clone this repo
- `cd` into this directory
- Run `docker build -t network-sniffer:allinone -f Dockerfile.allinone .`

#### Running the container
- Build the image
- Run `docker run -d --name netsniffer --network host --env-file ./src/.env network-sniffer:allinone`

#### Working with the network sniffer
The GoReplay application does not autostart by default. Instead you can start and stop it when you need it, like this:
- **Start**: `docker exec netsniffer sniffer on`
- **Stop**: `docker exec netsniffer sniffer off`
- **Status**: `docker exec netsniffer sniffer`

## Environment variables

Resurface uses two main environment variables:

- `USAGE_LOGGERS_URL` stores the Resurface database URL, which by default should be `http://localhost:7701/message`
- `USAGE_LOGGERS_RULES` stores a set of rules used to filter sensitive info when logging API calls. [Learn more](#protecting-user-privacy)

In addition, the `APP_PORT` environment variable tells the network sniffer where to listen in the host machine, and `VPC_MIRROR_DEVICE` corresponds to a virtual VXLAN interface for [VPC mirroring](#vpc-mirroring).

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
