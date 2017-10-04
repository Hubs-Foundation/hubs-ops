#!/usr/bin/env bash

HOST_TYPE=$1
ENVIRONMENT=$2

[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

REGION="us-west-1"

EC2_INFO=$(aws ec2 --region $REGION describe-instances)
BASTION_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.Tags | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-bastion\"))) | .[] | select(.State | .Code == 16) | .PublicIpAddress" | shuf | head -n1)
TARGET_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.Tags | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-hab\"))) | .[] | select(.State | .Code == 16) | .PrivateIpAddress" | shuf | head -n1)

ansible-playbook --ask-vault-pass -i "${TARGET_IP}," --ssh-common-args="-i ~/.ssh/mozilla_mr_id_rsa -o ProxyCommand=\"ssh -W %h:%p -i ~/.ssh/mozilla_mr_id_rsa ubuntu@${BASTION_IP}\"" -u ubuntu "${HOST_TYPE}-config.yml"

