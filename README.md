# goreplay
Log detailed API requests and responses from network traffic with GoReplay to your own [system of record](https://resurface.io).

## Requirements
- docker
- [Resurface](https://resurface.io/installation) (free docker container)

## Options
We offer three different alternatives to run Resurface alongside GoReplay:
- [All-in-one container](#all-in-one-container)
- [Sidecar container](#sidecar-container)
- [Use GoReplay directly in your host machine](#direct-approach-option)

### All-in-one container
This is the easiest option. Works great for demos, dev environments, and single-node solutions but it might not provide the flexibility needed in a production environment.

#### Building the container
- Clone this repo
- `cd` into the directory where you cloned it
- Run `docker build -t resurface:gor .`

#### Running the container
- Build the image
- Run:
  - **Linux**: `docker run -d --name resurface-gor --network host resurface:gor`
  - **macOS**: `docker run -d --name resurface-gor --add_host localhost:$(nslookup host.docker.internal) resurface:gor`

#### Working with the network sniffer
The GoReplay application does not autostart by default. Instead you can start and stop it when you need it, like this:
- Start: `docker exec goreplay-resurface sniffer on PORT`, where PORT is your application port.
- Stop: `docker exec goreplay-resurface sniffer off`
- Status: `docker exec goreplay-resurface sniffer`

### Sidecar container
This is the most flexible option. Works great when orchestrating different applications.

#### Building the container
- Clone this repo
- `cd` into the directory where you cloned it
- Run `docker build -t resurface:gor -f Dockerfile.sidecar .`

#### Running the containers
- Build the image
- Run `docker-compose up`

#### Working with the network sniffer
The GoReplay application does not autostart by default. Instead you can start and stop it when you need it, like this:
- Start: `docker exec goreplay-resurface sniffer on PORT`, where PORT is your application port.
- Stop: `docker exec goreplay-resurface sniffer off`
- Status: `docker exec goreplay-resurface sniffer`

### Direct approach option
This option allows you to the run GoReplay binary directly on your host machine.

#### Download the network sniffer application
- Download the tarball or binary file that corresponds to you system from the ~latest release~ [bin directory](https://github.com/resurfaceio/goreplay/tree/master/bin).
- Extract or install accordingly.

#### Running the network sniffer application
- Run `gor --input-raw $APP_PORT --input-track-response --output-resurface $USAGE_LOGGERS_URL --output-resurface-rules $USAGE_LOGGER_RULES`

## Environment variables

Resurface uses two main environment variables:

- `USAGE_LOGGERS_URL` stores the address to the database, which by default should be `http://localhost:4001/message`
- `USAGE_LOGGERS_RULES` stores a set of rules used to filter sensitive info when logging API calls. [Learn more](#protecting-user-privacy)

In addition, the `APP_PORT` environment variable tells the network sniffer where to listen in the host machine.

## Protecting User Privacy

Loggers always have an active set of <a href="https://resurface.io/logging-rules">rules</a> that control what data is logged
and how sensitive data is masked. All of the examples above apply a predefined set of rules (`include debug`),
but logging rules are easily customized to meet the needs of any application.

<a href="https://resurface.io/logging-rules">Logging rules documentation</a>

---
<small>&copy; 2016-2021 <a href="https://resurface.io">Resurface Labs Inc.</a></small>
