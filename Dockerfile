FROM alpine
ADD bin/gor_RESURFACE_LOGGER_x64.tar.gz  /bin/
ENTRYPOINT gor ${K8S_INPUT:---input-raw $VPC_MIRROR_DEVICE:$APP_PORT --input-raw-bpf-filter "(dst port $APP_PORT) or (src port $APP_PORT)"} --input-raw-track-response  --output-resurface $USAGE_LOGGERS_URL --output-resurface-rules "$(echo -e $USAGE_LOGGERS_RULES)"
