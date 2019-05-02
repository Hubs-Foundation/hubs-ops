#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: migrate_db.sh <environment>

Runs the pending database migration scripts for the given environment. (dev, prod, or local.)
"
  exit 1
fi

if [[ -z "$HUBS_OPS_SECRETS_PATH" ]]; then
  echo -e "You'll need to clone the ops secrets:

git clone https://git-codecommit.us-west-1.amazonaws.com/v1/repos/hubs-ops-secrets

Then set HUBS_OPS_SECRETS_PATH to point to the cloned repo."
  exit 1
fi

# TODO this should get a lot smarter -- if you are on a branch, disallow. If you have working changes, warn the user and require a flag.
git pull origin master

ENVIRONMENT=$1

REGION="us-west-1"

EC2_INFO=$(aws ec2 --region $REGION describe-instances)
BASTION_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.State ; .Name == \"running\"))) | map(select(any(.Tags // [] | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-bastion\"))) | .[] | .PublicIpAddress" | shuf | head -n1)

if [[ $ENVIRONMENT == "local" ]] ; then
  ansible-playbook -i "127.0.0.1," --extra-vars "env=${ENVIRONMENT} connection=local" -u ubuntu "migrate_db.yml"
else
  TARGET_IP=$(echo $EC2_INFO | jq -r ".Reservations | map(.Instances) | flatten | map(select(any(.State ; .Name == \"running\"))) | map(select(any(.Tags // [] | from_entries ; .[\"host-type\"] == \"${ENVIRONMENT}-util\"))) | .[] | .PrivateIpAddress" | shuf | head -n1)

  ansible-playbook --ask-vault-pass -i "${TARGET_IP}," --ssh-common-args="-i ~/.ssh/mozilla_mr_id_rsa -o ProxyCommand=\"ssh -W %h:%p -o StrictHostKeyChecking=no -i ~/.ssh/mozilla_mr_id_rsa ubuntu@${BASTION_IP}\"" --extra-vars "env=${ENVIRONMENT} connection=ssh secrets_path=${HUBS_OPS_SECRETS_PATH}" -u ubuntu "migrate_db.yml"
fi

