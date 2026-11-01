#!/usr/bin/env bash
# check.sh -- exercise 06: broken workloads
source "$(dirname "$0")/../../bin/lib.sh"

expect_ci checkout_api_status ImagePullBackOff "the image tag does not exist"
expect_ci worker_status CrashLoopBackOff "the container exits 1 on every start"
expect_match worker_restarts '[1-9][0-9]*' "any positive restart count"
expect_ci batch_renderer_status Pending "nothing schedules 32Gi"
expect_ci batch_renderer_memory 32Gi "the pod spec, not the node capacity"

require_cluster
kcheck "checkout-api is stuck on its image" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get pods -l app=checkout-api \
    -o jsonpath="{.items[0].status.containerStatuses[0].state.waiting.reason}") == ImagePullBackOff ]]'
kcheck "worker is in CrashLoopBackOff" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get pods -l app=worker \
    -o jsonpath="{.items[0].status.containerStatuses[0].state.waiting.reason}") == CrashLoopBackOff ]]'
kcheck "batch-renderer is Pending" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get pods -l app=batch-renderer \
    -o jsonpath="{.items[0].status.phase}") == Pending ]]'

finish
