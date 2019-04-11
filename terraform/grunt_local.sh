#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: grunt_local.sh <command> <module> [environment]

Runs the specified terragrunt command, just for the specified module, for the given environment.
This command includes any local changes, not just those that have landed in git.
"
  exit 1
fi

COMMAND=$1
MODULE=$2
ENVIRONMENT=$3

[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

pushd live/$ENVIRONMENT/$MODULE
terragrunt $COMMAND $4 $5 $6 $7 $8 $9 --terragrunt-source ../../../modules/$MODULE --terragrunt-download-dir ../../../.terragrunt_cache
popd
