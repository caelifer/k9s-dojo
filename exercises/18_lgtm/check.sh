#!/usr/bin/env bash
# check.sh -- exercise 18: wire the collector into the LGTM stack
source "$(dirname "$0")/../../bin/lib.sh"

ctx=aks-dojo-dev
require_cluster

expect lgtm_namespace observability "Loki, Tempo, Mimir and Grafana"
expect tempo_otlp_port 4317 "OTLP gRPC"
expect loki_port 3100 "HTTP API"
expect mimir_port 9009 "remote write endpoint"
expect lgtm_statefulsets 3 "loki, tempo, mimir"
expect datasource_count 3 "mimir, loki, tempo"
expect grafana_host grafana.dojo.local "the grafana ingress host"

# the backends the learner has to feed
kcheck "three LGTM StatefulSets are ready" \
  bash -c "[[ \$(kubectl --context $ctx -n observability get sts --no-headers | wc -l) == 3 &&
           \$(kubectl --context $ctx -n observability get sts -o jsonpath='{.items[*].status.readyReplicas}') == '1 1 1' ]]"
kcheck "grafana is running" \
  bash -c "[[ \$(kubectl --context $ctx -n observability get deploy grafana -o jsonpath='{.status.readyReplicas}') == 1 ]]"
kcheck "grafana Ingress routes grafana.dojo.local" \
  bash -c "kubectl --context $ctx -n observability get ing grafana -o jsonpath='{.spec.rules[0].host}' | grep -qx grafana.dojo.local"

# grafana's provisioned datasources must point at the same services
kcheck "grafana is provisioned with three datasources" \
  bash -c "kubectl --context $ctx -n observability get cm grafana-datasources -o jsonpath='{.data.datasources\.yaml}' | grep -c 'type: ' | grep -qx 3"
kcheck "grafana datasources target loki, tempo and mimir" \
  bash -c "d=\$(kubectl --context $ctx -n observability get cm grafana-datasources -o jsonpath='{.data.datasources\.yaml}');
           grep -q 'http://loki.observability.svc.cluster.local:3100' <<<\"\$d\" &&
           grep -q 'http://tempo.observability.svc.cluster.local:3200' <<<\"\$d\" &&
           grep -q 'http://mimir.observability.svc.cluster.local:9009/prometheus' <<<\"\$d\""

# what the learner wrote into the collector config
collector_config=$(kubectl --context "$ctx" -n pipeline get cm collector-config \
  -o jsonpath='{.data.collector\.yaml}' 2>/dev/null)

if [[ -z $collector_config ]]; then
  _fail "no collector-config ConfigMap in the pipeline namespace; run make apply N=17"
else
  check_config() {
    local pattern=$1 what=$2
    if grep -q -- "$pattern" <<<"$collector_config"; then
      _ok
    else
      _fail "collector config is missing $what"
    fi
  }
  check_config 'otlp/tempo' "the otlp/tempo exporter"
  check_config 'tempo.observability.svc.cluster.local:4317' "Tempo's OTLP gRPC endpoint"
  check_config 'otlphttp/loki' "the otlphttp/loki exporter"
  check_config 'loki.observability.svc.cluster.local:3100/otlp' "Loki's OTLP endpoint"
  check_config 'prometheusremotewrite/mimir' "the prometheusremotewrite/mimir exporter"
  check_config 'mimir.observability.svc.cluster.local:9009/api/v1/push' "Mimir's remote write endpoint"
  check_config 'memory_limiter' "the memory_limiter processor"
  check_config 'batch' "the batch processor"
  check_config 'traces:' "a traces pipeline"
  check_config 'metrics:' "a metrics pipeline"
  check_config 'logs:' "a logs pipeline"
fi

finish
