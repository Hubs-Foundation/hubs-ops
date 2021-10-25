#!/usr/bin/env bash

BOT_TYPE=$1
ENVIRONMENT=$2

[[ -z "$BOT_TYPE" ]] && BOT_TYPE=smoke
[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

REGION="us-west-1"

EC2_INFO=$(aws ec2 --region $REGION describe-instances)
BASTION_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.Tags // [] | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-bastion\"))) | .[] | select(.State | .Code == 16) | .PublicIpAddress" | shuf | head -n1)
TARGET_IPS=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.Tags // [] | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-bots_${BOT_TYPE}\"))) | .[] | select(.State | .Code == 16) | .PrivateIpAddress" | paste -d, -s -)

ansible-playbook -i "${TARGET_IPS}," --extra-vars "bot_type=${BOT_TYPE} env=${ENVIRONMENT}" --ssh-common-args="-i ~/.ssh/mozilla_mr_id_rsa -o ConnectTimeout=90 -o ProxyCommand=\"ssh -W %h:%p -i ~/.ssh/mozilla_mr_id_rsa -o ControlMaster=auto -o ControlPersist=600s -o ControlPath=\"~/.ssh/%r@%h:%p\" -o ConnectTimeout=90 -o StrictHostKeyChecking=no ubuntu@${BASTION_IP}\"" -u ubuntu "bots.yml"
