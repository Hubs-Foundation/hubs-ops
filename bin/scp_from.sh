#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: ssh_from.sh <hostname> <src-path> <dest-path> [environment]

Copys a file from remote src-path to local dest-path for hostname in environment.

Expects ssh-agent to have mozilla mr ssh key registered and present in ~/.ssh/mozilla_mr_id_rsa.
"
  exit 1
fi

HOST_TYPE_OR_NAME=$1
SRC=$2
DEST=$3
ENVIRONMENT=$4

[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

REGION="us-west-1"

EC2_INFO=$(aws ec2 --region $REGION describe-instances)
BASTION_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.State ; .Name == \"running\"))) | map(select(any(.Tags | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-bastion\"))) | .[] | .PublicIpAddress" | shuf | head -n1)

# it's a hostname
TARGET_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.State ; .Name == \"running\"))) | map(select(any(.Tags | from_entries ; .[\"Name\"] == \"${HOST_TYPE_OR_NAME}\"))) | .[] | .PrivateIpAddress" | shuf | head -n1)

scp -o ProxyCommand="ssh -W %h:%p -i ~/.ssh/mozilla_mr_id_rsa ubuntu@${BASTION_IP}" -i ~/.ssh/mozilla_mr_id_rsa "ubuntu@${TARGET_IP}:$SRC" "$DEST"
