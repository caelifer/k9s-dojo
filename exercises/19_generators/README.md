# 19 — Generate the telemetry, and collect the cluster's own

Exercises 17 and 18 built a pipeline and connected it to Loki, Tempo and Mimir.
Nothing has ever sent it a single span or datapoint. This one adds both halves of
what a production pipeline actually ingests:

- **application telemetry** — pods that generate synthetic OTEL data on purpose
- **cluster telemetry** — kube-state-metrics for object state and node-exporter
  for host metrics, scraped by the collector and shipped to Mimir

The full path you are assembling:

```
telemetrygen ---> collector:4317 --+
                                   +--> [memory_limiter, batch] --> tempo / loki / mimir
kube-state-metrics:8080 ------+    |
node-exporter:9100 ---------- +----+ (prometheus receiver, metrics pipeline)
                                        |
                                   grafana.dojo.local
```

## Part 1 — synthesize application telemetry

The generator is OpenTelemetry's own `telemetrygen`. It takes one signal per
invocation, so a pod that produces all three signals has three containers:

| Container | Subcommand | Goes to |
|---|---|---|
| `traces` | `telemetrygen traces` | collector gRPC 4317 |
| `metrics` | `telemetrygen metrics` | collector gRPC 4317 |
| `logs` | `telemetrygen logs` | collector gRPC 4317 |

Fill in `manifests/50-generators.yaml`:

- Deployment `synthetic-load`, 2 replicas, containers `traces`, `metrics`,
  `logs`, image
  `ghcr.io/open-telemetry/opentelemetry-collector-contrib/telemetrygen:v0.115.0`,
  each with `--otlp-endpoint collector.pipeline.svc.cluster.local:4317`,
  `--otlp-insecure`, `--rate 5`, `--duration 1h`.
- CronJob `telemetry-smoke`, schedule `*/10 * * * *`, one container running
  `traces --traces 5` against the same endpoint.

## Part 2 — collect the cluster's own telemetry

Application spans say nothing about whether a node is out of disk or whether a
StatefulSet is stuck at two of three replicas. That comes from two standard
exporters, and both have to be deployed by you:

| Source | Workload | Port | What it answers |
|---|---|---|---|
| kube-state-metrics | Deployment + ServiceAccount + ClusterRole | 8080 | desired vs ready replicas, pod phases, node conditions |
| node-exporter | DaemonSet with hostPath mounts | 9100 | CPU, memory, disk, network per node |

Fill in `manifests/60-cluster-telemetry.yaml` (RBAC included — kube-state-metrics
cannot list pods without it).

## Part 3 — teach the collector to scrape them

The collector you wired in exercise 18 only listens for OTLP. Scraping needs a
`prometheus` receiver, added to the same `collector-config` ConfigMap in
`exercises/17_pipeline/manifests/10-collector.yaml`:

```yaml
receivers:
  otlp: { ... }
  prometheus:
    config:
      scrape_configs:
        - job_name: kube-state-metrics
          static_configs:
            - targets: ["kube-state-metrics.pipeline.svc.cluster.local:8080"]
        - job_name: node-exporter
          static_configs:
            - targets: ["node-exporter.pipeline.svc.cluster.local:9100"]
service:
  pipelines:
    metrics:
      receivers: [otlp, prometheus]
```

Then apply everything and look at it:

```sh
make apply N=17     # collector + namespace
make apply N=19     # generators and cluster exporters
```

In k9s: `:deploy -n pipeline` (synthetic-load, kube-state-metrics), `:ds -n
pipeline` (node-exporter, one pod per node), `<enter>` on the DaemonSet to see
which nodes it covers, `:cm -n pipeline` and `<y>` on `collector-config` to see
the scrape configs you just wrote, `:sa` and `:clusterrole` for the RBAC.

## Questions

1. Which image do the generators run? (repository name is enough)
2. What is the exact OTLP endpoint they export to?
3. How many containers does each `synthetic-load` pod have?
4. What is the CronJob's schedule?
5. Which Service do the generators talk to?
6. Which port does kube-state-metrics serve on?
7. Which port does node-exporter serve on?
8. Which DaemonSet collects host metrics?

Fill in `answer.txt`, then `make check`.
