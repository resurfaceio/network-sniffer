FROM resurfaceio/resurface:2.3.1
ENV USAGE_LOGGERS_URL="http://localhost:4001/message" USAGE_LOGGERS_RULES="include debug" APP_PORT=3000
COPY src/goreplay.ini /etc/supervisord/goreplay.ini
COPY src/sniffer /usr/local/bin/sniffer
COPY bin/gor  /opt/goreplay/bin/gor
RUN chmod +x /usr/local/bin/sniffer