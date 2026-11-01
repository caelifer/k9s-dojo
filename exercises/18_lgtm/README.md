# 18 — Wire the pipeline into the LGTM stack

A pipeline that exports nowhere is a collector with a hobby. The cluster already
runs the backends it has to feed, in the `observability` namespace:

| Backend | Object | Ingest endpoint |
|---|---|---|
| Mimir (metrics) | StatefulSet `mimir` | `mimir.observability.svc.cluster.local:9009/api/v1/push` |
| Loki (logs) | StatefulSet `loki` | `loki.observability.svc.cluster.local:3100/otlp` |
| Tempo (traces) | StatefulSet `tempo` | `tempo.observability.svc.cluster.local:4317` (OTLP gRPC) |
| Grafana | Deployment `grafana` + Ingress | `grafana.dojo.local`, datasources already provisioned |

Those three StatefulSets are the L, T and M; Grafana is the G, and it is
provisioned from the `grafana-datasources` ConfigMap, so it already knows about
all three.

The naive mistake is one `otlphttp` exporter for everything: Tempo takes OTLP
gRPC, Loki takes OTLP/HTTP at a path, and Mimir wants Prometheus remote write.
Each signal therefore gets its own exporter and its own pipeline.

## Your task

Extend the collector configuration you wrote in exercise 17 — the
`collector-config` ConfigMap in `exercises/17_pipeline/manifests/10-collector.yaml`
— so that it:

1. keeps the `otlp` receiver;
2. adds the `batch` and `memory_limiter` processors;
3. defines three exporters:
   - `otlp/tempo` → `tempo.observability.svc.cluster.local:4317`
   - `otlphttp/loki` → `http://loki.observability.svc.cluster.local:3100/otlp`
   - `prometheusremotewrite/mimir` →
     `http://mimir.observability.svc.cluster.local:9009/api/v1/push`
4. declares three pipelines — `traces`, `metrics`, `logs` — each wiring the
   receiver through the processors to its exporter.

Then re-apply and look at the result:

```sh
make apply N=17
```

In k9s, `:cm -n pipeline` and `<y>` on `collector-config` shows what you wrote;
`:sts -n observability` shows the backends you are feeding, and `:ep -n
observability` shows their endpoints.

Finally, answer the inspection questions:

1. Which namespace holds Loki, Tempo, Mimir and Grafana?
2. Which port does Tempo accept OTLP gRPC on?
3. Which port does Loki's HTTP API listen on?
4. Which port does Mimir expose for writes?
5. How many StatefulSets run in `observability`?
6. How many datasources does Grafana start with (see `grafana-datasources`)?
7. Which host does the Grafana Ingress route?

Fill in `answer.txt`, then `make check`. The checker reads the live ConfigMap,
so an exporter with a wrong endpoint or a missing pipeline fails.
