#!/usr/bin/env bash
# check.sh -- exercise 04: two environments
source "$(dirname "$0")/../../bin/lib.sh"

expect dev_frontend_replicas 3 "the base manifest"
expect prod_frontend_replicas 5 "the prod overlay patches replicas"
expect prod_only_namespace analytics "created by cluster/prod/analytics.yaml"
expect dev_canary_image nginx:1.28-alpine "only dev has the canary"

require_cluster
kcheck "dev frontend has 3 replicas" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get deploy frontend \
    -o jsonpath="{.spec.replicas}") == 3 ]]'
kcheck "prod frontend has at least the 5 seed replicas" \
  bash -c '[[ $(kubectl --context aks-dojo-prod -n shop get deploy frontend \
    -o jsonpath="{.spec.replicas}") -ge 5 ]]'
kcheck "analytics exists on prod" \
  kubectl --context aks-dojo-prod get ns analytics
kcheck "analytics is absent on dev" \
  bash -c '! kubectl --context aks-dojo-dev get ns analytics 2>/dev/null'

finish
