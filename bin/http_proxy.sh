#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: http_proxy.sh <port> [environment]

Opens a SSH based HTTP proxy on the specified port to the specified environment

Expects ssh-agent to have mozilla mr ssh key registered and present in ~/.ssh/mozilla_mr_id_rsa.
"
  exit 1
fi

PORT=$1
ENVIRONMENT=$2

[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

REGION="us-west-1"

BASTION_IP=$(dig +short thirsty-dwarf.reticulum.io | shuf | head -n1)
echo $BASTION_IP

echo "ssh -i ~/.ssh/mozilla_mr_id_rsa -D $PORT "ubuntu@$BASTION_IP""
ssh -i ~/.ssh/mozilla_mr_id_rsa -D $PORT "ubuntu@$BASTION_IP"
