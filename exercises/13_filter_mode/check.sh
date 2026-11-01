#!/usr/bin/env bash
# check.sh -- exercise 13: filter and mark
source "$(dirname "$0")/../../bin/lib.sh"

expect filter_key / "the slash opens filter mode"
expect worker_rows 1 "only one worker pod exists"
expect wide_key ctrl-w "Toggle Wide"
expect_any extra_column ip node "wide adds IP, NODE, NOMINATED, READINESS"

require_cluster
kcheck "shop has exactly one worker pod to find" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get pods --no-headers \
    | grep -c worker-) == 1 ]]'

finish
