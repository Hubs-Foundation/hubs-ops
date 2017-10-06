#!/usr/bin/env bash

EXISTING_IP=""
NEW_HOSTNAME=""

HOSTED_ZONE_ID="Z26OTGLBBCAHK4"
HOSTED_ZONE_NAME="reticulum.io"

if [[ ! -z "$(hostname | grep $HOSTED_ZONE_NAME)" ]] ; then
  echo "Hostname already set, exiting."
  exit 0
fi

PUBLIC_IP=$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)
PRIVATE_IP=$(curl -s http://169.254.169.254/latest/meta-data/local-ipv4)
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//')

attempt_generate_hostname() {
  ADJECTIVE=$(cat /usr/share/dict/hostname-adjectives | shuf | head -n1)
  NOUN=$(cat /usr/share/dict/hostname-nouns | shuf | head -n1)

  NEW_HOSTNAME="${ADJECTIVE}-${NOUN}"
  DNS_IP=$(dig $NEW_HOSTNAME A +short)

  if [[ ! -z "$DNS_IP" ]] ; then
    EXISTING_IP=$(aws ec2 --region $REGION describe-instances | grep $DNS_IP)
  fi
}

attempt_generate_hostname

while [[ ! -z $EXISTING_IP ]]
do
  attempt_generate_hostname
done

echo "Setting hostname to ${NEW_HOSTNAME}"

if [[ ! $PUBLIC_IP == *"404"* ]] ; then
  ROUTE53_PUBLIC_RECORD="{ \"ChangeBatch\": { \"Changes\": [ { \"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"${NEW_HOSTNAME}.${HOSTED_ZONE_NAME}.\", \"Type\": \"A\", \"TTL\": 900, \"ResourceRecords\": [ { \"Value\": \"$PUBLIC_IP\" } ] } } ] } }"
  aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --cli-input-json "${ROUTE53_PUBLIC_RECORD}"
fi

ROUTE53_PRIVATE_RECORD="{ \"ChangeBatch\": { \"Changes\": [ { \"Action\": \"UPSERT\", \"ResourceRecordSet\": { \"Name\": \"${NEW_HOSTNAME}-local.${HOSTED_ZONE_NAME}.\", \"Type\": \"A\", \"TTL\": 900, \"ResourceRecords\": [ { \"Value\": \"$PRIVATE_IP\" } ] } } ] } }"
aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --cli-input-json "${ROUTE53_PRIVATE_RECORD}"

aws ec2 create-tags --region $REGION --resources "${INSTANCE_ID}" --tags "Key=Name,Value=${NEW_HOSTNAME}"
sudo hostname "$NEW_HOSTNAME.$HOSTED_ZONE_NAME"
