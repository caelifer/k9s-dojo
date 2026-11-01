#!/usr/bin/env bash
# check.sh -- exercise 20: UIs and dashboards
source "$(dirname "$0")/../../bin/lib.sh"

ctx=aks-dojo-dev
require_cluster

# 1. the learner's manifests must validate
if dry=$(kubectl --context "$ctx" apply --dry-run=server -f "$EX_DIR/manifests/" 2>&1); then
  _ok
else
  _fail "manifests do not validate: $(printf '%s' "$dry" | tail -3 | tr '\n' ' ')"
fi

# 2. answers read off the TUI
expect grafana_host grafana.dojo.local "the Grafana ingress host"
expect tempo_host tempo.dojo.local "the Tempo ingress host"
expect prebuilt_dashboards 3 "cluster overview, pipeline components, apm"
expect sidecar_container dashboard-sidecar "the k8s-sidecar container"
expect dashboards_path /var/lib/grafana/dashboards "the shared emptyDir"
expect my_dashboard_uid dojo-pipeline-slo "the uid you chose"

# 3. the UIs the LGTM deployment exposes
kcheck "grafana Ingress routes grafana.dojo.local to 3000" \
  bash -c "[[ \$(kubectl --context $ctx -n observability get ing grafana -o jsonpath='{.spec.rules[0].host}') == grafana.dojo.local &&
    \$(kubectl --context $ctx -n observability get ing grafana -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}') == 3000 ]]"
kcheck "tempo Ingress routes tempo.dojo.local to 3200" \
  bash -c "[[ \$(kubectl --context $ctx -n observability get ing tempo -o jsonpath='{.spec.rules[0].host}') == tempo.dojo.local &&
    \$(kubectl --context $ctx -n observability get ing tempo -o jsonpath='{.spec.rules[0].http.paths[0].backend.service.port.number}') == 3200 ]]"
kcheck "both UIs terminate TLS" \
  bash -c "[[ \$(kubectl --context $ctx -n observability get ing grafana tempo -o jsonpath='{.items[*].spec.tls[0].secretName}') == 'grafana-tls tempo-tls' ]]"

# 4. dashboard plumbing: sidecar, provider, prebuilt dashboards
kcheck "grafana runs the dashboard sidecar" \
  bash -c "kubectl --context $ctx -n observability get deploy grafana \
    -o jsonpath='{.spec.template.spec.containers[*].name}' | grep -qw dashboard-sidecar"
kcheck "the sidecar watches for the grafana_dashboard label" \
  bash -c "kubectl --context $ctx -n observability get deploy grafana \
    -o jsonpath='{.spec.template.spec.containers[?(@.name==\"dashboard-sidecar\")].env[*].value}' | grep -q grafana_dashboard"
kcheck "the file provider points at the dashboards directory" \
  bash -c "kubectl --context $ctx -n observability get cm grafana-dashboard-provider \
    -o jsonpath='{.data.provider\.yaml}' | grep -q '/var/lib/grafana/dashboards'"
kcheck "three prebuilt dashboards are labelled for the sidecar" \
  bash -c "[[ \$(kubectl --context $ctx -n observability get cm -l grafana_dashboard=1 --no-headers | wc -l) == 3 ]]"

prebuilt_k8s=$(kubectl --context "$ctx" -n observability get cm grafana-dashboard-k8s \
  -o jsonpath='{.data.k8s-cluster-overview\.json}' 2>/dev/null)
prebuilt_pipe=$(kubectl --context "$ctx" -n observability get cm grafana-dashboard-pipeline \
  -o jsonpath='{.data.pipeline-components\.json}' 2>/dev/null)

if python3 - "$prebuilt_k8s" <<'PY'
import json, sys
dash = json.loads(sys.argv[1])
panels = dash["panels"]
assert len(panels) >= 8, "cluster overview is thin"
queries = json.dumps(panels)
assert "kube_node_info" in queries or "kube_pod_status_phase" in queries, "no cluster state"
assert "node_cpu_seconds_total" in queries or "node_memory_MemAvailable_bytes" in queries, "no host metrics"
assert dash["uid"] == "dojo-k8s-overview"
PY
then
  _ok
else
  _fail "the prebuilt cluster overview dashboard is missing or incomplete"
fi

if python3 - "$prebuilt_pipe" <<'PY'
import json, sys
dash = json.loads(sys.argv[1])
queries = json.dumps(dash["panels"])
assert dash["uid"] == "dojo-pipeline-components"
assert "otelcol_exporter_queue_size" in queries
assert "otelcol_receiver_accepted_spans" in queries
PY
then
  _ok
else
  _fail "the prebuilt pipeline dashboard is missing or incomplete"
fi

# 5. the learner's own dashboard, as the cluster has it
slo=$(kubectl --context "$ctx" -n pipeline get cm grafana-dashboard-pipeline-slo \
  -o jsonpath='{.data.pipeline-slo\.json}' 2>/dev/null)

if [[ -z $slo ]]; then
  _fail "no grafana-dashboard-pipeline-slo ConfigMap in pipeline; run make apply N=20"
else
  if kubectl --context "$ctx" -n pipeline get cm grafana-dashboard-pipeline-slo \
    -o jsonpath='{.metadata.labels.grafana_dashboard}' | grep -qx 1; then
    _ok
  else
    _fail "the dashboard ConfigMap needs the grafana_dashboard: \"1\" label"
  fi
  if python3 - "$slo" <<'PY'
import json, sys
dash = json.loads(sys.argv[1])
assert dash.get("uid") == "dojo-pipeline-slo", "uid"
assert len(dash.get("panels") or []) >= 3, "at least three panels"
names = [v.get("name") for v in (dash.get("templating") or {}).get("list") or []]
assert "pod" in names, "a templating variable named pod"
blob = json.dumps(dash["panels"])
assert "otelcol_exporter_queue_size" in blob, "query the exporter queue"
assert '"uid": "mimir"' in blob or "'uid': 'mimir'" in blob, "use the mimir datasource"
assert '"uid": "loki"' in blob or "'uid': 'loki'" in blob, "add a loki logs panel"
PY
  then
    _ok
  else
    _fail "pipeline-slo.json must have uid, 3+ panels, a pod variable, a queue query, mimir and loki datasources"
  fi
fi

finish
