#!/usr/bin/env bash
# check.sh -- exercise 09: RBAC
source "$(dirname "$0")/../../bin/lib.sh"

expect service_account dojo-deployer "the SA in shop, used by metrics-agent"
expect role_name pod-reader "rules: get, list, watch on pods"
expect role_namespace shop "the Role is namespaced"
expect_any rbac_command rbac roles "the grouped view"

require_cluster
kcheck "dojo-deployer exists in shop" \
  kubectl --context aks-dojo-dev -n shop get serviceaccount dojo-deployer
kcheck "pod-reader grants get on pods" \
  bash -c 'kubectl --context aks-dojo-dev -n shop get role pod-reader \
    -o jsonpath="{.rules[0].verbs}" | grep -q get'
kcheck "the binding points at the service account" \
  bash -c 'kubectl --context aks-dojo-dev -n shop get rolebinding pod-reader \
    -o jsonpath="{.subjects[0].name}" | grep -q dojo-deployer'

finish
