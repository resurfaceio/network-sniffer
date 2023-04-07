#!/bin/bash
# © 2016-2023 Resurface Labs Inc.
#
# DESCRIPTION
# This script creates all the necessary resources to mirror application traffic to a Resurface instance on EKS.
# Specifically, it creates by default:
# - One AWS VPC traffic mirror filter (TMF) to be uses with Resurface traffic mirror sessions.
# - One AWS VPC traffic mirror target (TMT) for each node in a given EKS cluster
# - One AWS VPC traffic mirror session (TMS) for each:
#  - ECS task in a given list of tasks
#  - ECS task in a given ECS cluster
#  - AutoScaling group in a given list of AutoScaling groups
#  - EC2 instance in a given list of EC2 instances
# - One inbound rule to allow mirrored traffic from each source security group is added to the target security group
# - One outbound rule to allow mirrored traffic to the target security group is added to each source security group
# It can also accept a TMF ID, and one or several TMT IDs in which case their creation is skipped
# USAGE
# ./resurface-mirror-maker.sh
# ENVIRONMENT VARIABLES
# Mirror target:
# $MIRROR_TARGET_EKS_CLUSTER_NAME: Name of the EKS cluster running Resurface. Required if target ID(s) is not specified.
# $MIRROR_TARGET_EKS_NODEGROUP_NAME: Name of the node group where Resurface is running inside EKS cluster. Optional.
# $MIRROR_TARGET_ID: Traffic mirror target ID (Target should be associated with a valid ENI attached to one node of the target EKS cluster). Required if EKS cluster name is not specified.
# $MIRROR_TARGET_IDS: Comma-separated list of traffic mirror target IDs. Required only if neither EKS cluster name nor singular target ID are specified.
# $MIRROR_TARGET_SG: Security group for target instance(s). Optional. Overrides security group discovery if both target SG and EKS clsuter name are specified.
# Mirror filter:
# $MIRROR_FILTER_ID: Traffic mirror filter ID. Optional.
# Mirror sources:
# $MIRROR_SOURCE_ECS_CLUSTER_NAME: Name of ECS cluster running applications to capture API calls from. Optional.
# $MIRROR_SOURCE_ECS_TASKS: Comma-separated list of task IDs. Optional.
# $MIRROR_SOURCE_AUTOSCALING_GROUPS: Comma-separated list of autoscaling groups running applications to capture API calls from. Optional.
# $MIRROR_SOURCE_EC2_INSTANCES: Comma-separated list of IDs of EC2 instances running applications to capture API calls from. Optional.
# Other:
# $MIRROR_CUSTOM_VXLAN_PORT: Custom VXLAN port to use for each session. Defaults to 4789. Optional.
# $MIRROR_DEBUG_OUT: Enable debug messages to stdout
# $K8S_NAMESPACE: Namespace where the ConfigMap to be updated lives

[ -n "${MIRROR_DEBUG_OUT}" ] && echo -e "ENVIRONMENT VARIABLES:" \
  "\nMIRROR_TARGET_EKS_CLUSTER_NAME: ${MIRROR_TARGET_EKS_CLUSTER_NAME}" \
  "\nMIRROR_TARGET_EKS_NODEGROUP_NAME: ${MIRROR_TARGET_EKS_NODEGROUP_NAME}" \
  "\nMIRROR_TARGET_ID: ${MIRROR_TARGET_ID}" \
  "\nMIRROR_TARGET_IDS: ${MIRROR_TARGET_IDS}" \
  "\nMIRROR_TARGET_SG: ${MIRROR_TARGET_SG}" \
  "\nMIRROR_FILTER_ID: ${MIRROR_FILTER_ID}" \
  "\nMIRROR_SOURCE_ECS_CLUSTER_NAME: ${MIRROR_SOURCE_ECS_CLUSTER_NAME}" \
  "\nMIRROR_SOURCE_ECS_TASKS: ${MIRROR_SOURCE_ECS_TASKS}" \
  "\nMIRROR_SOURCE_AUTOSCALING_GROUPS: ${MIRROR_SOURCE_AUTOSCALING_GROUPS}" \
  "\nMIRROR_SOURCE_EC2_INSTANCES: ${MIRROR_SOURCE_EC2_INSTANCES}" \
  "\nMIRROR_CUSTOM_VXLAN_PORT: ${MIRROR_CUSTOM_VXLAN_PORT}" \
  "\nMIRROR_DEBUG_OUT: ${MIRROR_DEBUG_OUT}" \
  "\n"

# Helper functions
# Space-or-comma-separated unquoted list as string to comma-separated quoted list as string
csq() {
  [ $# -gt 0 ] && (echo "$@" | sed 's/^/"/;s/$/"/g;s/,/","/g;s/ /","/g') || echo "$@"
}

[ -n "${MIRROR_DEBUG_OUT}" ] && echo "Initial definitions"
# Initial definitions
# Traffic Mirror Filter ID
filter_id="${MIRROR_FILTER_ID}"

# Traffic Mirror Target IDs
if [ -n "${MIRROR_TARGET_ID}" ] && [ -n "${MIRROR_TARGET_IDS}" ]; then
  target_ids=${MIRROR_TARGET_ID},${MIRROR_TARGET_IDS}
elif [ -z "${MIRROR_TARGET_IDS}" ]; then
  target_ids=${MIRROR_TARGET_ID}
else
  target_ids=${MIRROR_TARGET_IDS}
fi
# Check for the existence of either EKS cluster name or target ID(s)
if [ -z "${MIRROR_TARGET_EKS_CLUSTER_NAME}" ] && [ -z "${target_ids}" ]; then
  echo "Error[TARGET_ID]: Must provide either MIRROR_TARGET_EKS_CLUSTER_NAME or TARGET_ID in environment" 1>&2
  exit 1
fi

# Target Security Group ID
# Check for the existence of either EKS cluster name or target security group ID
if [ -z "${MIRROR_TARGET_EKS_CLUSTER_NAME}" ] && [ -z "${MIRROR_TARGET_SG}" ]; then
  echo "Error[TARGET_SG]: Must provide either MIRROR_TARGET_EKS_CLUSTER_NAME or MIRROR_TARGET_SG in environment" 1>&2
  exit 1
fi
target_sgs="${MIRROR_TARGET_SG}"

# Custom VXLAN port. Port for UDP traffic between VXLAN tunnel endpoints. Defaults to 4789
mirror_port=${MIRROR_CUSTOM_VXLAN_PORT:-4789}

# Traffic Mirror Session IDs
# Get all existing Resurface TMS in your VPC
sessions=$(aws ec2 describe-traffic-mirror-sessions --filter=Name=description,Values="Mirrors traffic to Resurface instance" | jq -r '[.TrafficMirrorSessions[].TrafficMirrorSessionId] | unique | join(" ")')
# As comma-separated quoted values
csq_sessions=$(csq $sessions)

# Initialize VNI list with existing VNIs
vnis=($(aws ec2 describe-traffic-mirror-sessions --traffic-mirror-session-ids $sessions | jq -r '.TrafficMirrorSessions[].VirtualNetworkId'))

[ -n "${MIRROR_DEBUG_OUT}" ] && echo "Automatic filter creation/retrieval"
# Automatic filter creation/retrieval
if [ -z "${MIRROR_FILTER_ID}" ]; then
  # Check that filter hasn't been created yet
  filter_id=$(aws ec2 describe-traffic-mirror-filters --filters=Name=description,Values="Mirror filter for Resurface sniffer" | jq -r '[.TrafficMirrorFilters[] | .TrafficMirrorFilterId] | select(length == 1) | .[0]')
  if [ -z $filter_id ]; then
    filter_id=$(aws ec2 create-traffic-mirror-filter --description "Mirror filter for Resurface sniffer" | jq -r '.TrafficMirrorFilter.TrafficMirrorFilterId')
    {
      aws ec2 create-traffic-mirror-filter-rule --traffic-mirror-filter-id $filter_id --traffic-direction ingress --rule-number 100 --rule-action accept --protocol 6 --destination-cidr-block "0.0.0.0/0" --source-cidr-block "0.0.0.0/0" | jq -r '.TrafficMirrorFilterRule.TrafficMirrorFilterRuleId'
      aws ec2 create-traffic-mirror-filter-rule --traffic-mirror-filter-id $filter_id --traffic-direction egress --rule-number 100 --rule-action accept --protocol 6 --destination-cidr-block "0.0.0.0/0" --source-cidr-block "0.0.0.0/0" | jq -r '.TrafficMirrorFilterRule.TrafficMirrorFilterRuleId'
    } >/dev/null
  fi
# TODO - add support for custom rules
# https://docs.aws.amazon.com/cli/latest/reference/ec2/modify-traffic-mirror-filter-rule.html
fi
[ -z "${filter_id}" ] && echo "Error[FILTER_ID]: couldn't create mirror traffic filter. Consider providing MIRROR_FILTER_ID in environment" 1>&2 && exit 1

[ -n "${MIRROR_DEBUG_OUT}" ] && echo "Automatic target creation/retrieval"
# Automatic target creation
# EKS cluster name is provided
if [ -z "${target_ids}" ]; then
  [ -n "${MIRROR_DEBUG_OUT}" ] && echo "EKS cluster name is provided"
  # Get NodeGroups for EKS cluster
  eks_nodegroup_names=${MIRROR_TARGET_EKS_NODEGROUP_NAME:-$(aws eks list-nodegroups --cluster-name $MIRROR_TARGET_EKS_CLUSTER_NAME | jq -r '.nodegroups | join(" ")')}
  # if [ -z "${MIRROR_TARGET_EKS_NODEGROUP_NAME}" ]; then
  #   eks_nodegroup_names=
  # else
  #   eks_nodegroup_names=${MIRROR_TARGET_EKS_NODEGROUP_NAME}
  # fi
  # TODO - Use custom trap instead
  [ -z "${eks_nodegroup_names}" ] && echo "Error: couldn't retrieve node groups from EKS cluster ${MIRROR_TARGET_EKS_CLUSTER_NAME}" 1>&2 && exit 1
  [ -n "${MIRROR_DEBUG_OUT}" ] && echo "EKS nodegroup names: ${eks_nodegroup_names}"

  for node_group in $eks_nodegroup_names; do
    [ -n "${MIRROR_DEBUG_OUT}" ] && echo "EKS nodegroup name: ${node_group}"
    # Get AutoScaling Groups as comma-separated quoted values
    eks_csq_autoscaling_groups+=$(aws eks describe-nodegroup --nodegroup-name $node_group --cluster-name $MIRROR_TARGET_EKS_CLUSTER_NAME | jq -r '[.nodegroup.resources.autoScalingGroups[].name | tojson] | join(",")')","
  done
  eks_csq_asg_len=${#eks_csq_autoscaling_groups}
  [ -n "${MIRROR_DEBUG_OUT}" ] && echo "EKS AutoScaling Groups: ${eks_csq_autoscaling_groups}"
  
  [ $eks_csq_asg_len -gt 0 ] || (echo "Error: couldn't retrieve autoscaling groups from EKS cluster ${MIRROR_TARGET_EKS_CLUSTER_NAME}" 1>&2 && exit 1)  
  eks_csq_autoscaling_groups=${eks_csq_autoscaling_groups::$eks_csq_asg_len-1}

  # Get instances per ASG
  eks_instances=$(aws autoscaling describe-auto-scaling-groups | jq -r '[.AutoScalingGroups[] | select(.AutoScalingGroupName == ('$eks_csq_autoscaling_groups')) | .Instances[].InstanceId] | join(" ")')
  [ -z "${eks_instances}" ] && echo "Error: couldn't retrieve node instances from EKS cluster ${MIRROR_TARGET_EKS_CLUSTER_NAME}" 1>&2 && exit 1
  [ -n "${MIRROR_DEBUG_OUT}" ] && echo "EKS Instances: ${eks_instances}"

  # Get all ENIs per instance, except for "aws-K8S-" ENIs
  eks_enis=$(aws ec2 describe-instances --instance-ids $eks_instances | jq -r '[.Reservations[].Instances[].NetworkInterfaces[] | select(.Description | contains("aws-K8S-i") | not) | .NetworkInterfaceId] | join(" ")')
  [ -z "${eks_enis}" ] && echo "Error: couldn't retrieve ENIs from EKS cluster ${MIRROR_TARGET_EKS_CLUSTER_NAME}" 1>&2 && exit 1
  # ENIs as comma-separated quoted values
  eks_csq_enis=$(csq $eks_enis)

  [ -n "${MIRROR_DEBUG_OUT}" ] && echo "EKS ENIs: ${eks_csq_enis}"

  # Get existing TMTs for all defined ENIs
  tmt=($(aws ec2 describe-traffic-mirror-targets | jq -r '[.TrafficMirrorTargets[] | select(.NetworkInterfaceId=='$eks_csq_enis') | .TrafficMirrorTargetId] | unique | join(" ")'))

  # Create TMTs for each ENI. Errors raised when TMT already exists for a given ENI are not logged.
  {
    for eni in $eks_enis; do
      tmt+=($(aws ec2 create-traffic-mirror-target --network-interface-id $eni --description "Resurface sniffer" | jq -r '.TrafficMirrorTarget.TrafficMirrorTargetId'))
    done
  } 2>/dev/null

  target_ids=$(echo "${tmt[@]}" | sed 's/ /,/g')
  [ -z "${target_ids}" ] && echo "Error: couldn't retrieve/create mirror traffic targets for EKS cluster ${MIRROR_TARGET_EKS_CLUSTER_NAME}" 1>&2 && exit 1

  # Get security group(s) for target instances if not already defined
  [ -z "${target_sgs}" ] && target_sgs=$(aws ec2 describe-instances --instance-ids $eks_instances | jq -r '[.Reservations[].Instances[].SecurityGroups[].GroupId] | unique | join(" ")')
  [ -z "${target_ids}" ] && echo "Error: couldn't retrieve target security group for EKS cluster ${MIRROR_TARGET_EKS_CLUSTER_NAME}" 1>&2 && exit 1
fi

# ID of an existing TMT associated with an ENI attached to the instance running Resurface (hardcoded as f1 but change to fn to use the n-th target in the list)
target_id=$(echo $target_ids | cut -d "," -f1)
# TODO - finish adding support for multiple target IDs
# ID of the security group associated with the ENI attached to the instance running Resurface
target_sg=$(echo $target_sgs | cut -d " " -f1)

[ -n "${MIRROR_DEBUG_OUT}" ] && printf "FILTER ID: %s\nTARGET ID: %s\nTARGET SG: %s\nVXLAN PORT: %s\n" $filter_id $target_id $target_sg $mirror_port

# Make all existing Resurface sessions use the same target_id
# (This was put in place to prevent duplicate API call capture due to having two sessions with the same source and different targets.
# However, distributing sessions across multiple targets is better for perfomance.
# In order to do that, a check (for any session with same source and multiple valid targets from target_ids) must be performed instead of forcing the same target id)
if [ -n "${sessions}" ]; then
  # Get sessions with a target ID different from target_id
  another_target_sessions=$(aws ec2 describe-traffic-mirror-sessions --traffic-mirror-session-ids $sessions | jq -r '[.TrafficMirrorSessions[] | select(.TrafficMirrorTargetId=="'$target_id'" | not) | .TrafficMirrorSessionId] | unique | join(" ")')
  for session in $another_target_sessions; do
    # update TMS to have same target
    aws ec2 modify-traffic-mirror-session --traffic-mirror-session-id $session --traffic-mirror-target-id $target_id >/dev/null
  done
  # check that all Resurface TMS have the same target, log to stderr if not
  count=$(aws ec2 describe-traffic-mirror-sessions --traffic-mirror-session-ids $sessions --filter=Name=traffic-mirror-target-id,Values=$target_id | jq -r '.TrafficMirrorSessions | length')
  [ $count -ne $(echo $sessions | wc -w) ] && echo "Error: Not all traffic mirror sessions have the same mirror target" 1>&2
fi

# Traffic sources

# Get instances per ASG
csq_autoscaling_groups=$(csq "${MIRROR_SOURCE_AUTOSCALING_GROUPS}")
[ -z "${csq_autoscaling_groups}" ] && asg_instances="" || asg_instances=$(aws autoscaling describe-auto-scaling-groups | jq -r '[.AutoScalingGroups[] | select(.AutoScalingGroupName == ('$csq_autoscaling_groups')) | .Instances[].InstanceId] | join(" ")')

if [ -n "${MIRROR_SOURCE_ECS_CLUSTER_NAME}" ]; then
  # Get all tasks in ECS cluster if not already defined
  ecs_tasks=${MIRROR_SOURCE_ECS_TASKS:-$(aws ecs list-tasks --cluster $MIRROR_SOURCE_ECS_CLUSTER_NAME | jq -r '.taskArns | join(" ")')}
  if [ -n "${ecs_tasks}" ]; then
    # Get all ENIs attached to each task
    ecs_enis=$(aws ecs describe-tasks --cluster $MIRROR_SOURCE_ECS_CLUSTER_NAME --tasks $ecs_tasks | jq -r '[.tasks[].attachments[] | select((.type == "ElasticNetworkInterface") and (.status == "ATTACHED")) | .details[] | select(.name == "networkInterfaceId") | .value] | unique | join(" ")')
    
    # Get instance ID for all instances without ENI directly attached to them (i.e. not awsvpc network mode)
    ci_arns=$(aws ecs describe-tasks --cluster $MIRROR_SOURCE_ECS_CLUSTER_NAME --tasks $ecs_tasks | jq -r '[.tasks[] | select(.attachments | length == 0) | .containerInstanceArn] | unique | join(" ")')
    [ -n "${ci_arns}" ] && ecs_instances=$(aws ecs describe-container-instances --container-instances $ci_arns --cluster $MIRROR_SOURCE_ECS_CLUSTER_NAME | jq -r '[.containerInstances[].ec2InstanceId] | unique | join(" ")')
  fi
fi

# Get ENIs of both ASG and ECS instances
instances="${asg_instances} ${ecs_instances} $(echo $MIRROR_SOURCE_EC2_INSTANCES | sed 's/,/ /g')"
instances=$(echo $instances | sed 's/^ //g;s/ $//g')
[ -n "${instances}" ] && enis=$(aws ec2 describe-instances --instance-ids $instances | jq -r '[.Reservations[].Instances[].NetworkInterfaces[].NetworkInterfaceId] | join(" ")')

enis=$(echo "${ecs_enis} ${enis}" | sed 's/^ //g;s/ $//g')
[ -n "${MIRROR_DEBUG_OUT}" ] && echo "Source ENIs found: ${enis}"

for eni in $enis; do
  [ -n "${MIRROR_DEBUG_OUT}" ] && echo "Creating/retrieving sessions for ENI ${eni}"

  # Check if Resurface session exists for given ENI
  if [ -n "${csq_sessions}" ] && [ "$(aws ec2 describe-traffic-mirror-sessions | jq -r '.TrafficMirrorSessions[] | select((.NetworkInterfaceId=="'$eni'") and (.TrafficMirrorSessionId == ('$csq_sessions')))')" ]; then
    [ -n "${MIRROR_DEBUG_OUT}" ] && echo "Session already exists for ENI ${eni}"
    continue
  fi

  count=$(aws ec2 describe-traffic-mirror-sessions | jq -r '[.TrafficMirrorSessions[] | select(.NetworkInterfaceId=="'$eni'") | .TrafficMirrorSessionId] | unique | length')
  # IF ENI is the source of 3 TMS, log message and skip
  if [ $count -eq 3 ]; then
    echo "[$(date)] TASK: ${task} - ENI: ${eni} Network interface already has 3 traffic mirror sessions in place. Please delete at least one to set up as new traffic mirror session." 1>&2
    continue
  fi

  # Create a mirror session per ENI
  vni=$(aws ec2 create-traffic-mirror-session --description "Mirrors traffic to Resurface instance" --network-interface-id $eni --traffic-mirror-target-id $target_id --traffic-mirror-filter-id $filter_id --session-number 1 | jq -r '.TrafficMirrorSession.VirtualNetworkId' 2>/dev/null)

  # Add security group rules if session was created successfully
  if [ $vni ]; then
    # Get security groups associated with each ENI
    sgs=$(aws ec2 describe-network-interfaces --network-interface-ids $eni | jq -r '[.NetworkInterfaces[].Groups[].GroupId] | unique | join(" ")')
    for sg in $sgs; do
      {
        # Add a VXLAN outbound rule to each source security group
        aws ec2 authorize-security-group-egress --group-id $sg --source-group $target_sg --port $mirror_port --protocol udp
        # Add a VXLAN inbound rule to target security group for each source security group
        aws ec2 authorize-security-group-ingress --group-id $target_sg --source-group $sg --port $mirror_port --protocol udp
      } 2>/dev/null
    done
    vnis+=($vni)
  fi
done

# Update VNIs ConfigMap
echo -e "data:\n  vnis: ${vnis[@]:-\"\"}" > patch.yaml
[ -n "${MIRROR_DEBUG_OUT}" ] && echo "patch.yaml" && cat patch.yaml
kubectl patch configmap/vnis-config -n $K8S_NAMESPACE --patch-file patch.yaml

# Restart Sniffer DaemonSet
kubectl rollout restart $(kubectl get ds -n $K8S_NAMESPACE -o name | grep sniffer) -n $K8S_NAMESPACE

# TODO
# - Add support for VPC peering
# - Add support for TMT auto-delete (TMT are not deleted automatically when their corresponding ENI is deleted)
