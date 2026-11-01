#!/usr/bin/env bash
# check.sh -- exercise 07: quotas and limits
source "$(dirname "$0")/../../bin/lib.sh"

expect quota_pods 40 "spec.hard.pods"
expect quota_requests_cpu 4 "spec.hard.requests.cpu"
expect default_cpu_limit 250m "the LimitRange default, not the request"
expect_any quota_command quota resourcequotas rq "one of the accepted names"

require_cluster
kcheck "quota caps pods at 40" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get quota shop-compute \
    -o jsonpath="{.spec.hard.pods}") == 40 ]]'
kcheck "quota caps requests.cpu at 4" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get quota shop-compute \
    -o jsonpath="{.spec.hard.requests\.cpu}") == 4 ]]'
kcheck "limit range defaults cpu to 250m" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get limitrange shop-defaults \
    -o jsonpath="{.spec.limits[0].default.cpu}") == 250m ]]'

finish
