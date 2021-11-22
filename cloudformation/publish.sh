#!/usr/bin/env bash

if [[ -z "$HUBS_OPS_SECRETS_PATH" ]]; then
  echo -e "You'll need to clone the ops secrets:

git clone https://git-codecommit.us-west-1.amazonaws.com/v1/repos/hubs-ops-secrets

Then set HUBS_OPS_SECRETS_PATH to point to the cloned repo."
  exit 1
fi

cfn-flip stack.yaml - | ./prep-stack.js pro "$HUBS_OPS_SECRETS_PATH/packer/polycosm/manifest.aws.json" | cfn-flip -y - stack_injected.yaml
aws s3 cp --region us-west-1 --acl public-read --cache-control "no-cache" stack_injected.yaml s3://hubs-cloud/stack-pro.yaml 

cfn-flip stack.yaml - | ./prep-stack.js pro-single "$HUBS_OPS_SECRETS_PATH/packer/polycosm/manifest.aws.json" | cfn-flip -y - stack_injected.yaml
aws s3 cp --region us-west-1 --acl public-read --cache-control "no-cache" stack_injected.yaml s3://hubs-cloud/stack-pro-single.yaml 

cfn-flip stack.yaml - | ./prep-stack.js personal "$HUBS_OPS_SECRETS_PATH/packer/polycosm/manifest.aws.json" | cfn-flip -y - stack_injected.yaml
aws s3 cp --region us-west-1 --acl public-read --cache-control "no-cache" stack_injected.yaml s3://hubs-cloud/stack-personal.yaml 

cfn-flip stack.yaml - | ./prep-stack.js beta "$HUBS_OPS_SECRETS_PATH/packer/polycosm/manifest.aws-beta.json" | cfn-flip -y - stack_injected.yaml
aws s3 cp --region us-west-1 --acl public-read --cache-control "no-cache" stack_injected.yaml s3://hubs-cloud/stack-beta.yaml 

aws s3 cp --region us-west-1 --acl public-read --cache-control "no-cache" "$HUBS_OPS_SECRETS_PATH/packer/polycosm/files/polycosm_start.single.sh" s3://polycosm-assets-prod-77ae26402152f4ea/polycosm_start.single.sh
rm stack_injected.yaml
