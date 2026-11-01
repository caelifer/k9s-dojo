#!/usr/bin/env bash
# check.sh -- exercise 01: orientation
source "$(dirname "$0")/../../bin/lib.sh"

expect dojo_namespaces 3 "shop, payments, ops in every cluster"
expect ledger_namespace payments "ledger lives in payments"
expect_any contexts_command ctx contexts context "the command-mode entry"
expect warp_key w "the warp key from the help screen"

require_cluster
kcheck "shop namespace exists" kubectl --context aks-dojo-dev get ns shop
kcheck "ledger lives in payments" kubectl --context aks-dojo-dev -n payments get deploy ledger

finish
