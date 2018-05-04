#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: dns_deploy.sh <hosted-zone-name> [environment]

Updates the (temporary) de-facto default DNS CNAMEs for Janus IPs in the specified environment.

(dev-janus.<hosted-zone-name> and smoke-dev-janus.<hosted-zone-name>)
"
  exit 1
fi

ZONE=$1
ENVIRONMENT=$2

[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

REGION="us-west-1"

EC2_INFO=$(aws ec2 --region $REGION describe-instances)

JANUS_HOST_NAME=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.Tags // [] | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-ret\" and .[\"smoke\"] == null))) | .[] | select(.State | .Code == 16) | .Tags | from_entries | .Name" | sort | head -n1)
JANUS_SMOKE_HOST_NAME=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.Tags // [] | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-ret\" and .[\"smoke\"] == \"true\"))) | .[] | select(.State | .Code == 16) | .Tags | from_entries .Name" | sort | head -n1)

ansible-playbook -i "localhost," -c local -e "janus_host_name=$JANUS_HOST_NAME janus_smoke_host_name=$JANUS_SMOKE_HOST_NAME env=$ENVIRONMENT zone=$ZONE" "dns.yml"
