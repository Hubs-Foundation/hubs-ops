#!/usr/bin/env bash

if [[ -z "$HUBS_OPS_SECRETS_PATH" ]]; then
  echo -e "You'll need to clone the ops secrets:

git clone https://git-codecommit.us-west-1.amazonaws.com/v1/repos/hubs-ops-secrets

Then set HUBS_OPS_SECRETS_PATH to point to the cloned repo."
  exit 1
fi

# Build packer image, decrypting and removing key files across runs
gpg2 -o - -d $HUBS_OPS_SECRETS_PATH/packer/hab-base/secrets.tar.gz.gpg | tar xz && packer build image.json
rm -rf secrets
