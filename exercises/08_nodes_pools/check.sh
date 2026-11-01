#!/usr/bin/env bash
# check.sh -- exercise 08: nodes and agent pools
source "$(dirname "$0")/../../bin/lib.sh"

expect dev_node_count 2 "one system, one user pool"
expect userpool_instance_type Standard_D4s_v5 "the VMware family in the manifest"
expect systempool_zone 1 "topology.kubernetes.io/zone"
expect systempool_taint_key CriticalAddonsOnly "the system pool taint"
expect region westeurope "topology.kubernetes.io/region"

require_cluster
kcheck "dev has two nodes" \
  bash -c '[[ $(kubectl --context aks-dojo-dev get nodes --no-headers | wc -l) == 2 ]]'
kcheck "the user pool is labelled" \
  bash -c 'kubectl --context aks-dojo-dev get nodes -l agentpool=userpool \
    -o jsonpath="{.items[0].metadata.labels.node\.kubernetes\.io/instance-type}" | grep -q Standard_D4s_v5'
kcheck "the system pool is tainted" \
  bash -c 'kubectl --context aks-dojo-dev get nodes -l agentpool=systempool \
    -o jsonpath="{.items[0].spec.taints[0].key}" | grep -q CriticalAddonsOnly'

finish
