#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: ssh.sh <host-type|hostname> [environment]

Opens a SSH connection via the bastion to a random host of type <host-type> within specified environment or <hostname>.

Expects ssh-agent to have mozilla mr ssh key registered and present in ~/.ssh/mozilla_mr_id_rsa.
"
  exit 1
fi

HOST_TYPE_OR_NAME=$1
ENVIRONMENT=$2

[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

REGION="us-west-1"

EC2_INFO=$(aws ec2 --region $REGION describe-instances)
BASTION_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.Tags | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-bastion\"))) | .[] | select(.State | .Name == \"running\") | .PublicIpAddress" | shuf | head -n1)

if [[ $HOST_TYPE_OR_NAME == *"-"* ]] ; then
  # it's a hostname
  TARGET_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.Tags | from_entries ; .[\"Name\"] == \"${HOST_TYPE_OR_NAME}\"))) | .[] | select(.State | .Name == \"running\") | .PrivateIpAddress" | shuf | head -n1)
else
  # it's a host type
  TARGET_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.Tags | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-${HOST_TYPE_OR_NAME}\"))) | .[] | select(.State | .Name == \"running\") | .PrivateIpAddress" | shuf | head -n1)
fi

ssh -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/mozilla_mr_id_rsa ubuntu@${BASTION_IP}" -i ~/.ssh/mozilla_mr_id_rsa "ubuntu@${TARGET_IP}"
