# 20 — UIs and dashboards

The LGTM stack is running, but until now it was only reachable from inside the
cluster. This exercise is about the part people actually look at: exposed UIs and
dashboards that answer questions without writing a query.

## What is already exposed

| UI | Host | Object |
|---|---|---|
| Grafana (dashboards, datasources, Explore) | `grafana.dojo.local` | Ingress `observability/grafana` → `grafana:3000` |
| Tempo (trace search, TraceQL) | `tempo.dojo.local` | Ingress `observability/tempo` → `tempo:3200` |

Both are `nginx` Ingresses with TLS entries. There is no ingress controller in
this cluster, so the objects exist and validate but nothing answers on those
hosts; on a real cluster they are reachable.

For the same dashboards *live*, run `make ui` and open
`http://localhost:3000` — that stack serves the same JSON from this repository
(`cluster/base/dashboards/`) with real series from kube-state-metrics,
node-exporter and the OTLP generators.

## How dashboards get in

The Grafana pod runs two containers:

| Container | Role |
|---|---|
| `grafana` | the server, with `/var/lib/grafana/dashboards` as an emptyDir |
| `dashboard-sidecar` | watches **every namespace** for ConfigMaps labelled `grafana_dashboard=1`, writes their JSON keys into that directory |

A provisioning ConfigMap (`grafana-dashboard-provider`) points Grafana's file
provider at the same directory, so a labelled ConfigMap becomes a dashboard
without restarting anything. The cluster ships two prebuilt dashboards this way:

| Dashboard | UID | Answers |
|---|---|---|
| Kubernetes / Cluster overview | `dojo-k8s-overview` | nodes ready, pods by phase, node CPU/memory, restarts, logs, traces |
| Dojo / Pipeline components | `dojo-pipeline-components` | accepted vs sent spans, exporter queue, drops, per-replica throughput, backend health |
| Dojo / APM (spans & traces) | `dojo-apm` | spans/s per service, p95 latency, error ratio, service graph edges, recent and error traces |

## Your task

Write a third one: a service-level view of the pipeline itself.

Fill in `manifests/70-slo-dashboard.yaml` so the ConfigMap:

1. lives in `pipeline` and carries `grafana_dashboard: "1"` as a label;
2. holds `pipeline-slo.json` with uid `dojo-pipeline-slo` and title
   `Dojo / Pipeline SLO`;
3. has at least three panels;
4. declares a templating variable named `pod` (type `query`);
5. queries `otelcol_exporter_queue_size`;
6. uses the `mimir` datasource uid on at least one panel, and `loki` on a logs
   panel.

Then apply and look at it:

```sh
make apply N=20
```

In k9s:

- `:cm -n pipeline` — your dashboard ConfigMap, `<y>` to see the JSON;
- `:cm -n observability` — the two prebuilt dashboards, both labelled;
- `:deploy -n observability` and `<d>` on `grafana` — the two containers and the
  `dashboards` volume they share;
- `:ing -n observability` — the two UI hosts.

Answer from the TUI:

1. Which host exposes Grafana?
2. Which host exposes Tempo's trace explorer?
3. How many dashboards ship prebuilt (ConfigMaps labelled `grafana_dashboard=1`
   in `observability`)? (three: cluster overview, pipeline components, APM)
4. What is the sidecar container called?
5. Which path holds the rendered dashboard JSON inside the Grafana pod?
6. What uid did you give your dashboard?

### Finding the planted problems

With the live stack up (`make ui`), the dummy loader in `ui/loader/` keeps
hitting the backends and occasionally misbehaves on purpose. On the APM
dashboard:

- **Errors by service** — one service stands out; `<d>`/trace view on it leads to
  the failing span names (`payload.mimir_bad_query`, `payload.tempo_unknown_route`,
  `payload.loki_bad_push`, `payload.grafana_missing_dashboard`).
- **p95 latency by service** — `dojo-loader` jumps to about 1.2 s periodically;
  the span carries `loader.simulated_delay_seconds`, so a simulated slow
  dependency is never mistaken for real server time.
- **Collector export queue** and **Error span ratio** — what an operator watches
  while the above happens.

Fill in `answer.txt`, then `make check`.
