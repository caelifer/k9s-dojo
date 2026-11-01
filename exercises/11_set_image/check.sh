#!/usr/bin/env bash
# check.sh -- exercise 11: set image
source "$(dirname "$0")/../../bin/lib.sh"

expect image_key i "the Set Image key"
expect redis_image redis:7.4-alpine "the tag you typed"

require_cluster
kcheck "some redis pod now runs redis:7.4-alpine" \
  bash -c 'kubectl --context aks-dojo-dev -n shop get pods -l app=redis \
    -o jsonpath="{.items[*].spec.containers[0].image}" | grep -q "redis:7.4-alpine"'

finish
