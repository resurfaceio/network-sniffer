FROM resurfaceio/resurface:2.3.1
ENV USAGE_LOGGERS_URL="http://localhost:4001/message" USAGE_LOGGERS_RULES="include debug" APP_PORT=80 VPC_MIRROR_DEVICE=""
COPY src/goreplay.ini /etc/supervisord/goreplay.ini
COPY src/sniffer /usr/local/bin/sniffer
ADD bin/gor_RESURFACE_LOGGER_x64.tar.gz  /opt/goreplay/bin/
RUN chmod +x /usr/local/bin/sniffer
