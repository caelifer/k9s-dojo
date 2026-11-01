#!/usr/bin/env bash
# check.sh -- exercise 17: build and inspect an observability pipeline
source "$(dirname "$0")/../../bin/lib.sh"

ctx=aks-dojo-dev
require_cluster

# 1. lint the learner's manifests with a server-side dry run
if dry=$(kubectl --context "$ctx" apply --dry-run=server -f "$EX_DIR/manifests/" 2>&1); then
  _ok
else
  _fail "manifests do not validate: $(printf '%s' "$dry" | tail -3 | tr '\n' ' ')"
fi

# 2. answers read off the TUI
expect collector_pods 2 "two replicas"
expect first_collector_pod collector-0 "ordinal naming, not a hash"
expect pvc_count 2 "one claim per replica"
expect_ci pvc_state Bound "manual storage class binds to the static PVs"
expect headless_service collector "clusterIP: None"
expect ingress_host collector.dojo.local "the ingress host"
expect hpa_min_replicas 2 "minReplicas"
expect hpa_max_replicas 6 "maxReplicas"
expect agent_pods 2 "one pod per node in dev"
expect init_container init-config "the init container name"

# 3. live assertions
kcheck "collector StatefulSet is ready" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get sts collector -o jsonpath='{.status.readyReplicas}') == 2 ]]"
kcheck "collector Service is headless" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get svc collector -o jsonpath='{.spec.clusterIP}') == None ]]"
kcheck "two claims, both Bound" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get pvc --no-headers | wc -l) == 2 &&
           \$(kubectl --context $ctx -n pipeline get pvc -o jsonpath='{.items[*].status.phase}') == 'Bound Bound' ]]"
kcheck "claims come from volumeClaimTemplates" \
  bash -c "kubectl --context $ctx -n pipeline get sts collector \\
    -o jsonpath='{.spec.volumeClaimTemplates[0].metadata.name}' | grep -qx data"
kcheck "ingress routes the collector host on 4318" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get ing collector -o jsonpath='{.spec.rules[0].host}') == collector.dojo.local &&
           \$(kubectl --context $ctx -n pipeline get ing collector -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}') == 4318 ]]"
kcheck "ingress terminates TLS" \
  bash -c "kubectl --context $ctx -n pipeline get ing collector \\
    -o jsonpath='{.spec.tls[0].secretName}' | grep -qx collector-tls"
kcheck "HPA targets the StatefulSet, 2 to 6" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get hpa collector -o jsonpath='{.spec.scaleTargetRef.kind}') == StatefulSet &&
           \$(kubectl --context $ctx -n pipeline get hpa collector -o jsonpath='{.spec.minReplicas}') == 2 &&
           \$(kubectl --context $ctx -n pipeline get hpa collector -o jsonpath='{.spec.maxReplicas}') == 6 ]]"
kcheck "node-agent covers every node" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get ds node-agent -o jsonpath='{.status.numberReady}') == \$(kubectl --context $ctx get nodes --no-headers | wc -l) ]]"
kcheck "node-agent tolerates the system pool taint" \
  bash -c "kubectl --context $ctx -n pipeline get ds node-agent \\
    -o jsonpath='{.spec.template.spec.tolerations[*].key}' | grep -q CriticalAddonsOnly"
kcheck "collector has an init container" \
  bash -c "kubectl --context $ctx -n pipeline get sts collector \\
    -o jsonpath='{.spec.template.spec.initContainers[0].name}' | grep -qx init-config"

finish
