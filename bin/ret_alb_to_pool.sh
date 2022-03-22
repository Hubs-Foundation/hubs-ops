#!/usr/bin/env bash

set -e

HOST=$1
SECONDARY_HOST=$2
CORS_HOST=$3
POOL=$4
ENVIRONMENT=$5
[[ -z "$ENVIRONMENT" ]] && ENVIRONMENT=dev

REGION="us-west-1"

if [ -z "$HOST" ] || [ "$HOST" == "--help" ] || ( [ "$POOL" != "earth" ] && [ "$POOL" != "arbre" ] ); then
  echo -e "
Usage: ret_alb_to_pool.h <host> <secondary-host> <cors-host> <earth|arbre> [environment]

Flips the ret-alb in the given enviroment to route traffic to the given ret pool (eg "arbre") with the given primary and secondary host (eg hubs.mozilla.com, prod.reticulum.io). The other pool will have traffic routed to it from the smoke hostname.

This script is intended to be used to flip a new version of reticulum live, once it is available on the
other pool.
"
  exit 1
fi

LB_ARN=$(aws --region $REGION elbv2 describe-load-balancers --names $ENVIRONMENT-ret | jq -r ". | .LoadBalancers[0] | .LoadBalancerArn")
LISTENER_ARN=$(aws --region $REGION elbv2 describe-listeners --load-balancer-arn $LB_ARN | jq -r ". | .Listeners[] | select(.Port == 443) | .ListenerArn")
EARTH_RULE_ARN=$(aws --region us-west-1 elbv2 describe-rules --listener-arn $LISTENER_ARN | jq -r ". | .Rules | map(select(any(.Actions[] ; .TargetGroupArn | contains(\"$ENVIRONMENT-earth-ret\")))) | .[] | select(.Priority != \"default\") | .RuleArn")
EARTH_SMOKE_RULE_ARN=$(aws --region us-west-1 elbv2 describe-rules --listener-arn $LISTENER_ARN | jq -r ". | .Rules | map(select(any(.Actions[] ; .TargetGroupArn | contains(\"$ENVIRONMENT-earth-smoke-ret\")))) | .[] | select(.Priority != \"default\") | .RuleArn")
ARBRE_RULE_ARN=$(aws --region us-west-1 elbv2 describe-rules --listener-arn $LISTENER_ARN | jq -r ". | .Rules | map(select(any(.Actions[] ; .TargetGroupArn | contains(\"$ENVIRONMENT-arbre-ret\")))) | .[] | select(.Priority != \"default\") | .RuleArn")
ARBRE_SMOKE_RULE_ARN=$(aws --region us-west-1 elbv2 describe-rules --listener-arn $LISTENER_ARN | jq -r ". | .Rules | map(select(any(.Actions[] ; .TargetGroupArn | contains(\"$ENVIRONMENT-arbre-smoke-ret\")))) | .[] | select(.Priority != \"default\") | .RuleArn")

if [ $POOL == "earth" ]; then
  aws --region $REGION elbv2 modify-rule --rule-arn $EARTH_RULE_ARN --conditions Field=host-header,Values="$HOST,$SECONDARY_HOST,$CORS_HOST"
  aws --region $REGION elbv2 modify-rule --rule-arn $ARBRE_SMOKE_RULE_ARN --conditions Field=host-header,Values="smoke-$HOST,smoke-$CORS_HOST"
  aws --region $REGION elbv2 set-rule-priorities --rule-priorities "RuleArn=$EARTH_RULE_ARN,Priority=11" "RuleArn=$ARBRE_SMOKE_RULE_ARN,Priority=12" "RuleArn=$EARTH_SMOKE_RULE_ARN,Priority=13" "RuleArn=$ARBRE_RULE_ARN,Priority=14"
else
  aws --region $REGION elbv2 modify-rule --rule-arn $ARBRE_RULE_ARN --conditions Field=host-header,Values="$HOST,$SECONDARY_HOST,$CORS_HOST"
  aws --region $REGION elbv2 modify-rule --rule-arn $EARTH_SMOKE_RULE_ARN --conditions Field=host-header,Values="smoke-$HOST,smoke-$CORS_HOST"
  aws --region $REGION elbv2 set-rule-priorities --rule-priorities "RuleArn=$ARBRE_RULE_ARN,Priority=11" "RuleArn=$EARTH_SMOKE_RULE_ARN,Priority=12" "RuleArn=$ARBRE_SMOKE_RULE_ARN,Priority=13" "RuleArn=$EARTH_RULE_ARN,Priority=14"
fi
