#!/usr/bin/env bash
# check.sh -- exercise 02: contexts
source "$(dirname "$0")/../../bin/lib.sh"

expect dev_user clusterUser_rg-dojo-dev-weu_aks-dojo-dev "exact user name"
expect prod_resource_group rg-dojo-prod-weu "rg-dojo-prod-weu"
expect dev_subscription 8f2c1d34-0000-4b2a-9c1e-000000000001 "the long uuid"
expect arm_id_annotation aks.azure.com/arm-id "the annotation key"

require_cluster
kcheck "both contexts exist" \
  bash -c 'kubectl config get-contexts -o name | grep -qx aks-dojo-dev &&
           kubectl config get-contexts -o name | grep -qx aks-dojo-prod'
kcheck "prod context is reachable" kubectl --context aks-dojo-prod get ns kube-system
kcheck "dev nodes carry the ARM id annotation" \
  bash -c 'kubectl --context aks-dojo-dev get nodes \
    -o jsonpath="{.items[0].metadata.annotations.aks\.azure\.com/arm-id}" | grep -q /subscriptions/'

finish
