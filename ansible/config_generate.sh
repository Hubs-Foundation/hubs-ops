#!/usr/bin/env bash

if [[ -z "$1" ]]; then
  echo -e "
Usage: config_generate.sh <host-type>

Generates config for this host type into /hab/user
"
  exit 1
fi


# TODO this should get a lot smarter -- if you are on a branch, disallow. If you have working changes, warn the user and require a flag.
git pull origin master

HOST_TYPE=$1

ansible-playbook -i "127.0.0.1," --extra-vars "env=local connection=local secrets_path=." "${HOST_TYPE}-config.yml"
