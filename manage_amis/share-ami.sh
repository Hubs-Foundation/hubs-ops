# $(maws)
# ./list_amis.sh > amis.json
#
# $0 action user-id image-id region


action=$1
user_id=$2
image_id=$3
region=$4

if [[ -z "${action}" ||
          -z "${user_id}" ||
          -z "${image_id}" ||
          -z "${region}" ]]; then
  echo "Please specify an action, user id, image id, and region:";
  echo "  $0 <action> <user_id> <image_id> <region>";
  exit 0
fi

if [ "${action}" == "add" ]; then
  echo "Adding ${user_id} to ${image_id}";
  aws ec2 modify-image-attribute \
    --image-id "${image_id}" \
    --launch-permission "Add=[{UserId=${user_id}}]" \
    --region "${region}"
  exit 0
fi

if [ "${action}" == "remove" ]; then
  echo "Removing ${user_id} from ${image_id}";
  aws ec2 modify-image-attribute \
    --image-id "${image_id}" \
    --launch-permission "Remove=[{UserId=${user_id}}]" \
    --region "${region}"
  exit 0
fi

echo 'You must specify an action. ("add" or "remove")';
