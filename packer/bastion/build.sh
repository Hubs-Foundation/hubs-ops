#!/usr/bin/env bash

# Prompt for 2FA
echo -n "Enter 2FA secret: "
read -s twofactorsecret

echo ""
echo -n "Re-enter 2FA secret: "
read -s twofactorsecretagain
echo ""

if [ "$twofactorsecret" == "$twofactorsecretagain" ]
then
  packer build -var "twofactorsecret=$twofactorsecret" image.json
else
  echo ""
  echo ""
  echo "Secrets didn't match."
fi

