#!/usr/bin/env bash
# check.sh -- exercise 10: scale by editing
source "$(dirname "$0")/../../bin/lib.sh"

expect edit_key e "the Edit key"
expect replicas_after 7 "the number you typed"
expect_ci cluster_edited prod "prod is the cluster with 5 seed replicas"

require_cluster
kcheck "prod frontend is now at 7 replicas" \
  bash -c '[[ $(kubectl --context aks-dojo-prod -n shop get deploy frontend \
    -o jsonpath="{.spec.replicas}") == 7 ]]'
kcheck "prod frontend has 7 pods running" \
  bash -c '[[ $(kubectl --context aks-dojo-prod -n shop get pods -l app=frontend \
    --no-headers | wc -l) == 7 ]]'

finish
