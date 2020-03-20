#!/usr/bin/env bash

export NODE_NAME=$(echo $HOSTNAME | sed "s/\([^.]*\)\(.*\)$/\1-local\2/")

rm start_erl.data

RELEASE_MUTABLE_DIR=$HOME RELEASE_CONFIG_DIR=/hab/svc/reticulum/config NODE_COOKIE=$(curl -s "http://$NODE_NAME:9631/services" | jq -r ".[] | select(.service_group == \"reticulum.default@mozillareality\") | .cfg | .erlang | .node_cookie") LC_ALL=en_US.UTF-8 LANG=en_US.UTF-8 REPLACE_OS_VARS=true sudo -E $(hab pkg path mozillareality/reticulum)/bin/ret remote_console
