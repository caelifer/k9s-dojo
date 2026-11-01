#!/usr/bin/env bash
# check.sh -- exercise 03: views
source "$(dirname "$0")/../../bin/lib.sh"

expect frontend_replicas 3 "dev runs the base manifest"
expect frontend_image nginx:1.27-alpine "image with tag"
expect nodeport_service frontend-nodeport
expect nodeport 30080
expect redis_service_port 6379

require_cluster
kcheck "dev frontend wants 3 replicas" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get deploy frontend \
    -o jsonpath="{.spec.replicas}") == 3 ]]'
kcheck "dev frontend runs nginx:1.27-alpine" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get deploy frontend \
    -o jsonpath="{.spec.template.spec.containers[0].image}") == nginx:1.27-alpine ]]'
kcheck "frontend-nodeport is a NodePort service" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get svc frontend-nodeport \
    -o jsonpath="{.spec.type}") == NodePort ]]'

finish
