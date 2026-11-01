#!/usr/bin/env bash
# check.sh -- exercise 12: delete a pod
source "$(dirname "$0")/../../bin/lib.sh"

expect delete_key ctrl-d "the Delete key"
expect_ci owner_kind ReplicaSet "pods of a Deployment are owned by a ReplicaSet"

require_cluster
seed_file="$DOJO_ROOT/.dojo/seed-dev-frontend"
if [[ ! -r $seed_file ]]; then
  _fail "no seed record; run make setup again"
else
  seed=$(cat "$seed_file")
  # the replacement takes a moment; give the ReplicaSet time to converge
  for _ in {1..40}; do
    count=$(kubectl --context aks-dojo-dev -n shop get pods -l app=frontend \
      --no-headers 2>/dev/null | wc -l)
    current=$(kubectl --context aks-dojo-dev -n shop get pods -l app=frontend \
      -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)
    [[ $count == 3 ]] && break
    sleep 0.5
  done
  if [[ -z $current ]]; then
    _fail "no frontend pods in shop"
  elif [[ " $current " == *" $seed "* ]]; then
    _fail "frontend pod $seed is still there; delete it with <ctrl-d>"
  else
    _ok
  fi
  kcheck "the seeded pod $seed is gone" \
    bash -c "! kubectl --context aks-dojo-dev -n shop get pod $seed >/dev/null 2>&1"
  kcheck "three frontend pods exist (one is the replacement)" \
    bash -c '[[ $(kubectl --context aks-dojo-dev -n shop get pods -l app=frontend \
      --no-headers | wc -l) == 3 ]]'
fi

finish
