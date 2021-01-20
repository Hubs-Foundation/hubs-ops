if [[ -z "$HUBS_OPS_SECRETS_PATH" ]]; then
    echo "Must set HUBS_OPS_SECRETS_PATH environment variable."
    exit 0
fi
manifest=$(find $HUBS_OPS_SECRETS_PATH -type f -iregex '.*manifest.aws-beta.*')
cat $manifest | jq '
[
  .builds
    | .[-1]
    | .artifact_id
    | split(",")
    | .[]
    | split(":")
    | {
        region: .[0],
        ami_id: .[1]
      }
]
'
