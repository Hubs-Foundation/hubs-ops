#!/bin/bash
# Helper functions for interacting with Hubs infrastructure.

# hab-run [plan-dir]
# Loads the most-recently-built Habitat .hart package into the local running Habitat supervisor,
# first stopping and unloading any existing version of the same package. Starts the package running.
function hab-run {
    local PLAN_DIR=${1:-.}
    local RESULTS_DIR=$PLAN_DIR/results
    local RESULTS_ENV=$RESULTS_DIR/last_build.env
    (export $(cat $RESULTS_ENV | xargs) && sudo -E hab svc unload $pkg_ident)
    (export $(cat $RESULTS_ENV | xargs) && sudo -E hab pkg install $RESULTS_DIR/$pkg_artifact)
    (export $(cat $RESULTS_ENV | xargs) && sudo -E hab svc load $pkg_ident)
    (export $(cat $RESULTS_ENV | xargs) && sudo -E hab svc start $pkg_ident)
}

# hab-build-and-run [plan-dir]
# Builds a Habitat plan and runs the output locally using hab-run.
function hab-build-and-run {
    local PLAN_DIR=${1:-.}
    hab pkg build $PLAN_DIR && hab-run $PLAN_DIR
}

# moz-ec2 [env] [asg]
# Lists active hosts from EC2, displaying environment, ASG, name, private IP, and public IP.
function moz-ec2 {
    local FILTERS="Name=instance-state-name,Values=running"
    if [ ! -z "$1" ]
    then
        FILTERS="$FILTERS Name=tag:env,Values=$1"
    fi
    if [ ! -z "$2" ]
    then
        FILTERS="$FILTERS Name=tag:aws:autoscaling:groupName,Values=$1-$2"
    fi
    local ALL=$(aws ec2 describe-instances --filters $FILTERS)
    OUTPUT=$(jq -r '.Reservations | map(.Instances) | flatten | .[] | [((.Tags//[])[]|select(.Key=="env")|.Value) // "null", ((.Tags//[])[]|select(.Key=="aws:autoscaling:groupName")|.Value) // "null", ((.Tags//[])[]|select(.Key=="Name")|.Value) // "null", .PrivateIpAddress // "null", .PublicIpAddress // "null"] | @tsv' <<< "$ALL")
    echo "${OUTPUT}" | sort -k2,2 -k3,3 | column -t
}

# moz-host env asg
# Gets the name of a random host from EC2 with the given environment and ASG.
function moz-host {
    moz-ec2 $1 $2 | shuf | head -n 1 | awk '{print $3}'
}

# moz-proxy cmd env ...cmd-args
# Proxies the given OpenSSH command through the given environment's bastion host.
function moz-proxy {
    $1 -o ProxyJump="$(moz-host $2 bastion).reticulum.io" "${@:3}"
}

# moz-ssh-into target ...cmd-args
# SSHes into the given target internal hostname or IP through its bastion host, e.g. `moz-ssh dazzling-druid`.
function moz-ssh-into {
    local ALL_INSTANCES=$(moz-ec2)
    local DESTINATION=$(echo "$ALL_INSTANCES" | grep "$1")
    local DESTINATION_ENV=$(echo "$DESTINATION" | awk "{print \$1}")
    local DESTINATION_HOST=$(echo "$DESTINATION" | awk "{print \$3}")
    local BASTION=$(echo "$ALL_INSTANCES" | awk "/$DESTINATION_ENV-bastion/ {print \$3}")
    ssh -o ProxyJump="$BASTION.reticulum.io" "$DESTINATION_HOST-local.reticulum.io" "${@:2}"
}

# moz-tunnel env asg local-port remote-port ...cmd-args
# Opens an SSH tunnel to a random host in the given environment and ASG.
function moz-tunnel {
    local ENV_INSTANCES=$(moz-ec2 $1)
    local DESTINATION=$(echo "$ENV_INSTANCES" | awk "/$1-$2/ {print \$3}")
    local BASTION=$(echo "$ENV_INSTANCES" | awk "/$1-bastion/ {print \$3}")
    ssh -L "$3:$DESTINATION-local.reticulum.io:$4" "$BASTION.reticulum.io" "${@:5}"
}

# Creates a tunnel to the CI host's web interface on port 8088.
alias moz-ci='moz-tunnel dev ci 8088 8080'

# Proxies SSH over a bastion host, e.g. `moz-ssh prod dazzling-druid-local.reticulum.io`.
alias moz-ssh='moz-proxy ssh'

# Proxies SCP over a bastion host, e.g. `moz-scp prod dazzling-druid-local.reticulum.io:~/core core`.
alias moz-scp='moz-proxy scp'
