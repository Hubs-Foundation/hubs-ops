#!/usr/bin/env bash

if [[ -z "$HUBS_OPS_SECRETS_PATH" ]]; then
  echo -e "You'll need to clone the ops secrets:

git clone https://git-codecommit.us-west-1.amazonaws.com/v1/repos/hubs-ops-secrets

Then set HUBS_OPS_SECRETS_PATH to point to the cloned repo."
  exit 1
fi

cfn-flip stack.yaml - | ./inject-amis.js "$HUBS_OPS_SECRETS_PATH/packer/polycosm/manifest.json" | cfn-flip -y - stack_injected.yaml
aws s3 cp --region us-west-1 --acl public-read --cache-control "no-cache" stack_injected.yaml s3://hubs-cloud/stack.yaml 
rm stack_injected.yaml
