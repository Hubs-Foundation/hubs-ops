#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: config_deploy.sh <host-type> [environment]

Performs a config deploy to the Habitat cluster to update configurations for the specified host type.
"
  exit 1
fi

# TODO this should get a lot smarter -- if you are on a branch, disallow. If you have working changes, warn the user and require a flag.
git pull origin master

HOST_TYPE=$1
ENVIRONMENT=$2

[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

REGION="us-west-1"

EC2_INFO=$(aws ec2 --region $REGION describe-instances)
BASTION_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.State ; .Name == \"running\"))) | map(select(any(.Tags | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-bastion\"))) | .[] | .PublicIpAddress" | shuf | head -n1)
TARGET_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.State ; .Name == \"running\"))) | map(select(any(.Tags | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-hab\"))) | .[] | .PrivateIpAddress" | shuf | head -n1)

ansible-playbook --ask-vault-pass -i "${TARGET_IP}," --ssh-common-args="-i ~/.ssh/mozilla_mr_id_rsa -o ProxyCommand=\"ssh -W %h:%p -o StrictHostKeyChecking=no -i ~/.ssh/mozilla_mr_id_rsa ubuntu@${BASTION_IP}\"" --extra-vars "env=${ENVIRONMENT}" -u ubuntu "${HOST_TYPE}-config.yml"

