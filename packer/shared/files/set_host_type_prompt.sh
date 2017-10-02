#!/usr/bin/env bash

if [[ ! -f ~/.aws_instance_id ]] ; then
        curl -s "http://169.254.169.254/latest/meta-data/instance-id" > ~/.aws_instance_id
fi

if [[ ! -f ~/.aws_region ]] ; then
        curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone | sed 's/[a-z]$//' > ~/.aws_region
fi

if [[ ! -f ~/.aws_host_type ]] ; then
        aws ec2 --region $(cat ~/.aws_region) describe-instances |  jq -r ".Reservations | map(.Instances) | flatten | .[] | select(.InstanceId == \"$(cat ~/.aws_instance_id)\") | .Tags | .[] | select(.Key == \"host-type\") | .Value " > ~/.aws_host_type
fi

export PS1="\[\033[01;34m\]$(cat ~/.aws_host_type) $PS1"
