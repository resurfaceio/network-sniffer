#!/bin/sh

device=${NET_DEVICE:-$VPC_MIRROR_DEVICE}
ports=${APP_PORTS:-$APP_PORT}
mode=$SNIFFER_ENGINE
debug=$SNIFFER_DEBUG_ENABLED
verbosity=${SNIFFER_DEBUG_VERBOSITY:=0}
export_to=${SNIFFER_DEBUG_EXPORT:=none}

bpf() {
  bpf_ports=$(echo $1 | sed 's/,/ or /g')
  echo "(dst port ($bpf_ports)) or (src port ($bpf_ports))"
}

rules() {
  echo "$(echo -e $USAGE_LOGGERS_RULES)"
}

inputs() {
  options="--input-raw $device:$ports"

  if [[ "$mode" == "mirror" ]]; then
    options="${options} --input-raw-engine vxlan"
    options="${options} --input-raw-vxlan-port ${SNIFFER_MIRROR_VXLANPORT:-4789}"
    vnis=$(echo $SNIFFER_MIRROR_VNIS | sed 's/,/ /g')
    for vni in $vnis; do
      options="${options} --input-raw-vxlan-vni $vni"
    done
  #else if [[ mode == "k8s" ]]; then
  # currently, all the logic is in helm _helpers.tpl
  # Takes pod/svc/label maps and builds options.
  # In order to move that here, a yaml parser is needed.
  # Then, we need to make values into a configmap on helm charts so they can be use by this script.
  # For now, we can keep using K8S_INPUT
  #  "k8s://service:"
  #  "--input-raw-k8s-nomatch-nocap"
  #  "--input-raw-ignore-interface"
  #  "--input-raw-k8s-skip-ns"
  #  "--input-raw-k8s-skip-svc"
  elif [[ "$mode" == "k8s" ]]; then
    # options=$K8S_INPUT
    options="${K8S_INPUT} --input-raw-track-response"
  else
    options="${options} --input-raw-track-response"
    options="${options} --input-raw-bpf-filter "
  fi

  echo $options
}

outputs() {
  options="--output-resurface $USAGE_LOGGERS_URL"

  if [[ "$debug" == "true" ]]; then
    if [ "$verbosity" -gt 0 ]; then
      options="${options} --verbose ${verbosity}"
    fi
    if [ "$verbosity" -ge 1 ]; then
      options="${options} --http-pprof :8181"
    fi
    if [ "$verbosity" -ge 2 ]; then
      options="${options} --output-stdout"
    fi

    if [ "${export_to}" != "none" ]; then
      if [ "${export_to}" == "s3" ]; then
        options="${options} --output-file s3://sniffer-debug-logs/${SNIFFER_DEBUG_DEAL_ID}/%Y-%m-%d.gz"
      elif [ "${export_to}" == "local" ]; then
        options="${options} --output-file ./%Y-%m-%d.gz"
      elif [ "${export_to}" == "http" ]; then
        options="${options} --output-http ${SNIFFER_DEBUG_HTTP_ENDPOINT}"
      else
        echo 'Invalid export option. Supported values are "s3", "local", "http", or "none"'
        exit 1
      fi
    fi
  fi

  options="${options} --output-resurface-rules "

  echo $options
}

if [[ "$mode" == "mirror" || "$mode" == "k8s" ]]; then
  gor $(inputs) $(outputs) "$(rules)"
else
  gor $(inputs) "$(bpf $ports)" $(outputs) "$(rules)"
fi
