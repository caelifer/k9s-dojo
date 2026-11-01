#!/usr/bin/env bash
# bin/simulate-faults.sh -- keep the two broken shop workloads broken.
#
# kwok has no kubelet: its controller reports every pod as Running. A real
# cluster would show the checkout-api pods stuck on a missing image tag and the
# worker pod in a restart loop. This watcher rewrites those two statuses every
# few seconds, which is also what makes a deleted pod come back broken, exactly
# as it would on a real cluster.
#
# usage: simulate-faults.sh [--once]
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
export KUBECONFIG="$ROOT/.dojo/kubeconfig"
ENVS=${DOJO_ENVS:-"dev prod"}

patch_checkout() {
  local ctx=$1 pod
  for pod in $(kubectl --context "$ctx" -n shop get pods -l app=checkout-api -o name 2>/dev/null); do
    kubectl --context "$ctx" -n shop patch "$pod" --subresource=status --type=merge -p '{
      "status": {
        "phase": "Pending",
        "conditions": [
          {"type": "PodScheduled", "status": "True"},
          {"type": "Initialized", "status": "True"},
          {"type": "Ready", "status": "False", "reason": "ContainersNotReady"},
          {"type": "ContainersReady", "status": "False", "reason": "ContainersNotReady"}
        ],
        "containerStatuses": [{
          "name": "api",
          "ready": false,
          "restartCount": 0,
          "image": "ghcr.io/k9s-dojo/checkout-api:1.4.2",
          "imageID": "",
          "state": {"waiting": {
            "reason": "ImagePullBackOff",
            "message": "Back-off pulling image \"ghcr.io/k9s-dojo/checkout-api:1.4.2\""
          }}
        }]
      }
    }' >/dev/null 2>&1
  done
}

# A real crash loop increments the restart counter; kwok does not, so the count
# is derived from how long this watcher has been running. Without it the restart
# rate stays at zero and the dashboards look calm while pods keep crashing.
STARTED=$(date +%s)

patch_worker() {
  local ctx=$1 pod restarts
  restarts=$(( 6 + ($(date +%s) - STARTED) / 30 ))
  for pod in $(kubectl --context "$ctx" -n shop get pods -l app=worker -o name 2>/dev/null); do
    kubectl --context "$ctx" -n shop patch "$pod" --subresource=status --type=merge -p '{
      "status": {
        "phase": "Running",
        "conditions": [
          {"type": "PodScheduled", "status": "True"},
          {"type": "Initialized", "status": "True"},
          {"type": "Ready", "status": "False", "reason": "ContainersNotReady"},
          {"type": "ContainersReady", "status": "False", "reason": "ContainersNotReady"}
        ],
        "containerStatuses": [{
          "name": "worker",
          "ready": false,
          "restartCount": '"$restarts"',
          "image": "alpine:3.20",
          "imageID": "",
          "state": {"waiting": {
            "reason": "CrashLoopBackOff",
            "message": "back-off 5m0s restarting failed container=worker"
          }}
        }]
      }
    }' >/dev/null 2>&1
  done
}

sweep() {
  local env ctx
  for env in $ENVS; do
    ctx="aks-dojo-$env"
    kubectl --context "$ctx" version >/dev/null 2>&1 || continue
    patch_checkout "$ctx"
    patch_worker "$ctx"
  done
}

if [[ ${1-} == --once ]]; then
  sweep
  exit 0
fi

trap 'exit 0' TERM INT
while true; do
  sweep
  sleep 3
done
