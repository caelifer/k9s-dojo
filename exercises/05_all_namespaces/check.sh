#!/usr/bin/env bash
# check.sh -- exercise 05: all namespaces
source "$(dirname "$0")/../../bin/lib.sh"

expect all_namespaces_key 0 "the number row, not a letter"
expect namespace_with_most_deployments shop "six deployments, the next has one"
expect coredns_replicas 2 "two coredns pods per cluster"
expect kube_system_daemonsets 2 "kube-proxy and csi-azuredisk-node"

require_cluster
kcheck "shop holds six deployments in dev" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get deploy --no-headers | wc -l) == 6 ]]'
kcheck "kube-system has two DaemonSets in dev" \
  bash -c '[[ $(kubectl --context aks-dojo-dev -n kube-system get ds --no-headers | wc -l) == 2 ]]'

finish
