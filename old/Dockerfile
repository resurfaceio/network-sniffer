FROM alpine
ADD bin/gor_RESURFACE_LOGGER_x64.tar.gz  /bin/
ENTRYPOINT gor ${K8S_INPUT:---input-raw $NET_DEVICE:$APP_PORTS --input-raw-bpf-filter "(dst port $(echo $APP_PORTS | sed 's/,/ or /g')) or (src port $(echo $APP_PORTS | sed 's/,/ or /g'))"} --input-raw-track-response  --output-resurface $USAGE_LOGGERS_URL --output-resurface-rules "$(echo -e $USAGE_LOGGERS_RULES)"
