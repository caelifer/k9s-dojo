#!/usr/bin/env bash
# check.sh -- exercise 19: generate telemetry and collect cluster metrics
source "$(dirname "$0")/../../bin/lib.sh"

ctx=aks-dojo-dev
endpoint=collector.pipeline.svc.cluster.local:4317
require_cluster

# 1. the learner's manifests must validate
if dry=$(kubectl --context "$ctx" apply --dry-run=server -f "$EX_DIR/manifests/" 2>&1); then
  _ok
else
  _fail "manifests do not validate: $(printf '%s' "$dry" | tail -3 | tr '\n' ' ')"
fi

# 2. answers read off the TUI
expect_text generator_image telemetrygen "the OpenTelemetry load generator"
expect otlp_endpoint "$endpoint" "collector Service, gRPC port"
expect generator_containers 3 "one container per signal"
expect cron_schedule '*/10 * * * *' "every ten minutes"
expect collector_service collector "the headless collector Service"
expect ksm_port 8080 "kube-state-metrics http-metrics"
expect node_exporter_port 9100 "node-exporter metrics"
expect node_exporter_workload node-exporter "the host-metrics DaemonSet"

# 3. the application generators
kcheck "synthetic-load runs 2 replicas" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get deploy synthetic-load -o jsonpath='{.spec.replicas}') == 2 ]]"
kcheck "one container per signal" \
  bash -c "[[ \"\$(kubectl --context $ctx -n pipeline get deploy synthetic-load \
    -o jsonpath='{.spec.template.spec.containers[*].name}')\" == 'traces metrics logs' ]]"
kcheck "every container runs telemetrygen" \
  bash -c "kubectl --context $ctx -n pipeline get deploy synthetic-load \
    -o jsonpath='{.spec.template.spec.containers[*].image}' | tr ' ' '\n' | grep -c telemetrygen | grep -qx 3"
kcheck "every container targets the collector gRPC endpoint" \
  bash -c "kubectl --context $ctx -n pipeline get deploy synthetic-load \
    -o jsonpath='{.spec.template.spec.containers[*].args}' | grep -o '$endpoint' | wc -l | grep -qx 3"
kcheck "every container exports insecurely (in-cluster plaintext)" \
  bash -c "kubectl --context $ctx -n pipeline get deploy synthetic-load \
    -o jsonpath='{.spec.template.spec.containers[*].args}' | grep -o -- --otlp-insecure | wc -l | grep -qx 3"
kcheck "each container runs its own subcommand" \
  bash -c "c=\$(kubectl --context $ctx -n pipeline get deploy synthetic-load \
    -o jsonpath='{.spec.template.spec.containers[*].args}');
    grep -q traces <<<\"\$c\" && grep -q metrics <<<\"\$c\" && grep -q logs <<<\"\$c\""
kcheck "the smoke CronJob runs every ten minutes" \
  bash -c "kubectl --context $ctx -n pipeline get cj telemetry-smoke \
    -o jsonpath='{.spec.schedule}' | grep -qx '\\*/10 \\* \\* \\* \\*'"
kcheck "the CronJob sends a burst of traces" \
  bash -c "kubectl --context $ctx -n pipeline get cj telemetry-smoke \
    -o jsonpath='{.spec.jobTemplate.spec.template.spec.containers[0].args}' | grep -q -- '--traces'"

# 4. cluster telemetry: kube-state-metrics
kcheck "kube-state-metrics runs and serves 8080" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get deploy kube-state-metrics \
    -o jsonpath='{.spec.template.spec.containers[0].image}' | grep -c kube-state-metrics) == 1 &&
    \$(kubectl --context $ctx -n pipeline get svc kube-state-metrics -o jsonpath='{.spec.ports[0].port}') == 8080 ]]"
kcheck "kube-state-metrics uses its own service account" \
  bash -c "kubectl --context $ctx -n pipeline get deploy kube-state-metrics \
    -o jsonpath='{.spec.template.spec.serviceAccountName}' | grep -qx kube-state-metrics"
kcheck "the ClusterRole allows listing pods and nodes" \
  bash -c "r=\$(kubectl --context $ctx get clusterrole dojo-kube-state-metrics \
    -o jsonpath='{.rules[*].resources}');
    grep -q pods <<<\"\$r\" && grep -q nodes <<<\"\$r\"; \
    v=\$(kubectl --context $ctx get clusterrole dojo-kube-state-metrics -o jsonpath='{.rules[*].verbs}');
    grep -q watch <<<\"\$v\""
kcheck "the ClusterRoleBinding points at that account" \
  bash -c "kubectl --context $ctx get clusterrolebinding dojo-kube-state-metrics \
    -o jsonpath='{.subjects[0].name}' | grep -qx kube-state-metrics"

# 5. cluster telemetry: node-exporter
kcheck "node-exporter serves 9100" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get svc node-exporter \
    -o jsonpath='{.spec.ports[0].port}') == 9100 ]]"
kcheck "node-exporter covers every node" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get ds node-exporter \
    -o jsonpath='{.status.numberReady}') == \$(kubectl --context $ctx get nodes --no-headers | wc -l) ]]"
kcheck "node-exporter tolerates every taint" \
  bash -c "kubectl --context $ctx -n pipeline get ds node-exporter \
    -o jsonpath='{.spec.template.spec.tolerations[0].operator}' | grep -qx Exists"
kcheck "node-exporter mounts the host filesystems read-only" \
  bash -c "kubectl --context $ctx -n pipeline get ds node-exporter \
    -o jsonpath='{.spec.template.spec.volumes[*].hostPath.path}' | tr ' ' '\n' | grep -qx /proc"

# 6. the collector has to scrape them, and the chain has to stay complete
kcheck "the collector Service exposes both OTLP ports" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get svc collector \
    -o jsonpath='{.spec.ports[*].port}') == '4317 4318' ]]"
kcheck "the collector Service selects running pods" \
  bash -c "[[ \$(kubectl --context $ctx -n pipeline get endpoints collector \
    -o jsonpath='{.subsets[*].addresses[*].ip}' | wc -w) -ge 2 ]]"
kcheck "the collector scrapes kube-state-metrics and node-exporter" \
  bash -c "c=\$(kubectl --context $ctx -n pipeline get cm collector-config \
    -o jsonpath='{.data.collector\.yaml}');
    grep -q 'prometheus:' <<<\"\$c\" &&
    grep -q 'kube-state-metrics.pipeline.svc.cluster.local:8080' <<<\"\$c\" &&
    grep -q 'node-exporter.pipeline.svc.cluster.local:9100' <<<\"\$c\""
kcheck "the metrics pipeline keeps both receiver sources" \
  bash -c "kubectl --context $ctx -n pipeline get cm collector-config \
    -o jsonpath='{.data.collector\.yaml}' | grep -q 'receivers: \[otlp, prometheus\]'"
kcheck "the collector still exports to Tempo, Loki and Mimir" \
  bash -c "c=\$(kubectl --context $ctx -n pipeline get cm collector-config \
    -o jsonpath='{.data.collector\.yaml}');
    grep -q 'otlp/tempo' <<<\"\$c\" && grep -q 'otlphttp/loki' <<<\"\$c\" &&
    grep -q 'prometheusremotewrite/mimir' <<<\"\$c\""
kcheck "the LGTM backends are ready to receive" \
  bash -c "[[ \$(kubectl --context $ctx -n observability get sts \
    -o jsonpath='{.items[*].status.readyReplicas}') == '1 1 1' ]]"

finish
