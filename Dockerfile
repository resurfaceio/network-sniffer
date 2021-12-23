FROM alpine
ADD bin/gor_RESURFACE_LOGGER_x64.tar.gz  /bin/
ENTRYPOINT gor --input-raw $VPC_MIRROR_DEVICE:$APP_PORT --input-raw-track-response --input-raw-bpf-filter "(dst port $APP_PORT) or (src port $APP_PORT)" --output-resurface $USAGE_LOGGERS_URL --output-resurface-rules "$(echo -e $USAGE_LOGGERS_RULES)"
