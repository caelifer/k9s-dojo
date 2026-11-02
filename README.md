# k9s-dojo

Twenty exercises for the [k9s](https://k9scli.io) terminal UI, built like
[ziglings](https://codeberg.org/ziglings/exercises): numbered exercises you edit,
a checker that refuses to pass until the work is actually done, and a throwaway
cluster that `make setup` builds for you.

The cluster is shaped like Azure AKS: two clusters in one kubeconfig, AKS-style
context and user names, agent pools with zones and instance types, an `MC_…`
resource group label on every node, AKS add-ons in `kube-system`, per-namespace
quotas and limit ranges, a StatefulSet with its own PersistentVolumes, an
Ingress with TLS, three workloads that are broken on purpose, and a capstone
where you build an observability pipeline yourself.

## Prerequisites

Everything the repository runs on is pinned in `mise.toml` and installed by
mise — no system packages, no manual release downloads:

| Tool | Version source | Used for |
|---|---|---|
| k9s | `mise.toml` | the TUI you are learning |
| kubectl | `mise.toml` | seeding, live checks |
| kwokctl | `mise.toml` | builds both simulated clusters |
| python 3.12 + PyYAML | `mise.toml` + `requirements.txt` | cluster and kubeconfig plumbing |
| uv | `mise.toml` | installs the Python dependency |
| jq | `mise.toml` | JSON in the scripts |

```sh
make deps      # mise install + uv pip install -r requirements.txt
```

`make setup` runs `make deps` first, so a fresh clone only needs two host-level
things that cannot be versioned per project:

| Host tool | Why it stays on the host |
|---|---|
| mise | it is the version manager itself |
| podman (+ podman-compose) | a container runtime with rootless setup, kernel and cgroup integration; `make ui` uses it |

Interactive shells: `eval "$(mise activate bash)"` (or just use `make`, whose
recipes already run inside `mise exec`).

### Base requirements (any Linux distribution)

Nothing here is tied to a distribution. `make doctor` checks all of this and
prints what to fix:

| Requirement | Why | Check |
|---|---|---|
| kernel with user namespaces | rootless containers for `make ui` | `/proc/sys/user/max_user_namespaces` > 0 |
| cgroup v2 (recommended) | rootless resource limits | `stat -fc %T /sys/fs/cgroup` = `cgroup2fs` |
| `/etc/subuid` + `/etc/subgid` for your user | rootless id mapping | `grep ^$(id -un): /etc/subuid` |
| bash 4+, coreutils, `curl`, `git`, `awk`, `sed`, `grep` | the scripts are bash | `make doctor` |
| mise | installs k9s, kubectl, kwokctl, python, uv, jq | `mise --version` |
| a container engine with compose | only `make ui` needs it | `podman compose version` or `docker compose version` |

Install those two host-level pieces however your distribution prefers — the
repository never invokes a package manager:

```sh
# Debian/Ubuntu   sudo apt install podman podman-compose
# Fedora/RHEL     sudo dnf install podman podman-compose
# Arch            sudo pacman -S podman podman-compose
# openSUSE        sudo zypper install podman podman-compose
# Alpine          sudo apk add podman podman-compose
```

On macOS the clusters run on the Mac while the containers run inside the engine's
VM, so the stack reaches the API server through `host.containers.internal`.
`make cluster` / `make reset` refresh the two containers that hold that
kubeconfig; `make doctor` reports a stale port. If panels stay empty, the VM is
not forwarding to the Mac's loopback — `make doctor` prints the `podman machine
ssh -- curl …` probe to confirm.

Docker works too: `DOJO_ENGINE=docker make ui` runs the same stack through
`docker compose`, and `bin/ui` adds `ui/compose.docker.yaml`, which maps the host
gateway name docker needs for the kube-state-metrics scrape (podman resolves
`host.containers.internal` on its own).

No root, no VM. `make setup` is idempotent and `make teardown` removes both
clusters.

## Quick start

```sh
make doctor    # host prerequisites: kernel, userns, ports, toolchain
make setup     # two clusters, seeded, in about 20 seconds
make ui        # live Grafana (http://localhost:3000) and Tempo (:3200)
make tui       # k9s against aks-dojo-dev with this repo's config
make next      # which exercise is due
make check     # verify it
make list      # progress through all twenty
make destroy   # stop the UIs, delete the clusters, remove .dojo
```

## The cluster

| | `aks-dojo-dev` | `aks-dojo-prod` |
|---|---|---|
| Kubeconfig user | `clusterUser_rg-dojo-dev-weu_aks-dojo-dev` | `clusterUser_rg-dojo-prod-weu_aks-dojo-prod` |
| Namespaces | `shop`, `payments`, `ops` (+ cluster's own) | same + `analytics` |
| Node pools | systempool (D2s_v5, zone 1), userpool (D4s_v5, zone 1) | systempool + 3× D8s_v5, zones 1-3 |
| `shop` workloads | frontend ×3, frontend-canary, redis, checkout-api ×2, worker, batch-renderer | frontend ×5, redis, checkout-api ×2, worker, batch-renderer |
| Stateful workload | `payments/storefront-db` StatefulSet, 2 replicas, one bound PVC each | same |
| Edge | `shop/shop-edge` Ingress, host `shop.dojo.local`, TLS | same |
| Observability | `observability` namespace: Loki, Tempo, Mimir StatefulSets, Grafana (2 containers) with two prebuilt dashboards, `grafana.dojo.local` and `tempo.dojo.local` Ingresses | same |
| Broken on purpose | checkout-api (ImagePullBackOff), worker (CrashLoopBackOff), batch-renderer (Pending/unschedulable) | same |

The LGTM stack (Loki for logs, Tempo for traces, Mimir for metrics, Grafana on
top) is seeded because it is the consumer the capstone wires into: the exercise
is to make your collector feed all three backends, which each speak a different
protocol.

Everything else is normal Kubernetes: a ResourceQuota and LimitRange per
namespace, a ServiceAccount plus Role and RoleBinding in `shop`, coredns,
kube-proxy and csi-azuredisk-node in `kube-system`, one CronJob and one Job in
`payments`, and four static PersistentVolumes (`storageClassName: manual`) that
satisfy claims because there is no CSI driver here.

`bin/cluster` merges both clusters into `.dojo/kubeconfig` and deletes kwok's own
contexts, so `:ctx` shows exactly the two AKS-shaped entries. Your real
`~/.kube/config` is never touched.

## How grading works

Each exercise has four files:

| File | Meaning |
|---|---|
| `README.md` | the task, in k9s terms |
| `answer.txt` | what you fill in, `key: value` lines |
| `check.sh` | what `make check` runs |
| `solution.txt` | reference answers, `make solution N=10` |

Checks are of two kinds, and a single exercise usually uses both:

- **answers** — values you read off the TUI (statuses, replicas, labels, keys).
- **live state** — assertions against the API server, so a guessed answer still
  fails if the cluster does not agree. Exercises 10-12 are graded only on live
  state, because "I scaled it" is not a text answer.

The checker prints every expectation it evaluates, in order, and exits non-zero
until all of them hold. `.dojo/completed` records finished exercises; delete a
line to redo one, delete the file to start over.

`make selftest` is the maintainer's check: it fills every answer from its
reference solution, applies the capstone manifests, performs the cluster edits
that exercises 10-12 ask for, runs all seventeen checkers, and then restores the
templates and the cluster.

## Exercises

| No | Topic | Graded by |
|---|---|---|
| 01 | Orientation: contexts, namespaces, command mode | answers |
| 02 | Contexts: two clusters, resource groups, subscriptions | answers |
| 03 | Views: deployments, services, ports | answers |
| 04 | Two environments: same app, different overlays | answers + state |
| 05 | All namespaces, DaemonSets, add-ons | answers + state |
| 06 | Broken workloads: ImagePullBackOff, CrashLoopBackOff, Pending | answers + state |
| 07 | Quotas and limit ranges | answers + state |
| 08 | Nodes: agent pools, zones, taints | answers + state |
| 09 | RBAC: service accounts, roles, bindings | answers + state |
| 10 | Edit and scale a deployment in prod | state |
| 11 | Set image on a running pod | state |
| 12 | Delete a pod, watch its owner replace it | state |
| 13 | Filter, mark, wide columns | answers |
| 14 | Aliases for command mode | config file |
| 15 | Skins | config file |
| 16 | Plugins: shell out from k9s | config file + command |
| 17 | Capstone: build and inspect an observability pipeline | manifests + state |
| 18 | Capstone: wire the pipeline into the LGTM stack | live config + state |
| 19 | Capstone: generate application telemetry and collect cluster metrics | manifests + live config |
| 20 | Capstone: UIs and dashboards | manifests + dashboard JSON |

## The capstone (exercise 17)

The last exercise is the whole tutorial in one go, shaped like Datadog's
Kubernetes [observability pipeline
reference](https://www.datadoghq.com/architecture/observability-pipelines-kubernetes-deployment/):
a StatefulSet of OpenTelemetry collectors with one volume per replica, a
headless Service for stable per-pod DNS, an Ingress with TLS for the OTLP/HTTP
port, a DaemonSet node agent that tolerates the system pool taint, and an HPA
pointed at the StatefulSet.

You write the manifests yourself — `exercises/17_pipeline/manifests/` ships
three files full of `TODO`s and one complete file — apply them with
`make apply N=17`, watch the objects appear in k9s, and then answer inspection
questions from `:sts`, `:pvc`, `:svc`, `:ing`, `:hpa` and `:ds`.

Exercise 18 closes the loop: the same cluster runs an LGTM stack in the
`observability` namespace, and your collector has to export traces to Tempo over
OTLP gRPC, logs to Loki over OTLP/HTTP, and metrics to Mimir over Prometheus
remote write — three exporters, three pipelines, checked against the live
ConfigMap. Grafana is already provisioned with those three datasources via the
`grafana-datasources` ConfigMap, so the collector is the only missing link.

Exercise 19 supplies the data. Two kinds, because a cluster pipeline needs both:
`telemetrygen` pods that synthesize traces, metrics and logs against the
collector (one container per signal, plus a CronJob smoke burst), and the
cluster's own telemetry — kube-state-metrics with the RBAC it needs, and a
node-exporter DaemonSet with hostPath mounts. The collector learns a `prometheus`
receiver and scrapes both, so the metrics pipeline goes from
`receivers: [otlp]` to `receivers: [otlp, prometheus]`.

The last exercise is about what people actually look at. The LGTM deployment
exposes two UIs — `grafana.dojo.local` for dashboards and `tempo.dojo.local` for
trace search — and ships two prebuilt dashboards as labelled ConfigMaps that a
`k8s-sidecar` container renders into Grafana's dashboards directory:

| Dashboard | Covers |
|---|---|
| Kubernetes / Cluster overview | nodes ready, pods by phase, node CPU and memory, restarts per pod, pods waiting by reason, a Problematic-pods table (namespace/pod/phase/reason/restarts, colour-coded: orange transient, red error; click a pod to load its events), and a bottom pane that shows the selected pod's logs and Kubernetes events, logs, traces |
| Dojo / Pipeline components | accepted vs sent spans, exporter queue, drops, per-replica throughput, backend health, the log stream and a traces-through-the-pipeline table |
| Dojo / APM (spans & traces) | spans/s per service, p95 latency, error ratio, service-graph edges, plus recent and error trace tables (TraceQL over Tempo, trace IDs clickable) |

You add the third one: a service-level dashboard for the pipeline itself, written
as a labelled ConfigMap and checked by parsing the JSON the cluster holds.

Grading is a server-side `kubectl apply --dry-run=server` over your files plus
live assertions on every object, so neither invalid YAML nor a guessed answer
passes. Reference manifests are in `exercises/17_pipeline/solution/`.

## What the simulated kubelet cannot do

kwok runs a real API server with simulated nodes: no container is ever created.
That is what makes the whole tutorial instant and privilege-free, and it is also
its limit.

| k9s key | On this cluster | On a real AKS cluster |
|---|---|---|
| `<l>` logs | API error, shown verbatim | live container log |
| `<p>` previous logs | API error | the crashed container's log |
| `<s>` shell | API error | interactive shell |
| `<shift-f>` port-forward | local port opens, nothing answers | real tunnel |
| `<d>` describe | works, events down to the ARM id | same |
| `<e>`, `<i>`, `<ctrl-d>` | real API writes | same |

Because there is no kubelet, the two broken `shop` workloads would look healthy.
`bin/simulate-faults.sh` (started by `make setup`, stopped by `make teardown`)
rewrites their status every three seconds, which is also why a deleted
`checkout-api` pod comes back broken, exactly as it would for real.

## Live UIs

The cluster objects describe what a real AKS cluster would run, but kwok has no
kubelet, so nothing inside it serves HTTP. `make ui` therefore runs the same LGTM
stack on the host with rootless Podman, wired to the dojo API server, so the
dashboards show live data while you work:

| UI | URL | Notes |
|---|---|---|
| Grafana | `http://localhost:3000` | dashboards in the **Dojo** folder, Explore, APM view, anonymous admin |
| Tempo | `http://localhost:3200` | trace search / TraceQL |
| Mimir, Loki | `:9009`, `:3100` | APIs only, no UI |
| OTLP in | `localhost:4317`, `localhost:4318` | send your own spans with `telemetrygen` or an app |

Every generating component declares a `service.name` — `frontend` and
`checkout-api` for traces (one of them deliberately erroring), `worker` for logs,
`payments-ledger` for metrics, `pipeline-collector` and `node-agent` in the cluster
manifests — and the collector inserts a fallback for anything that arrives
without one, so no APM view shows "unknown service". Tempo's metrics-generator
turns those spans into `traces_spanmetrics_*` and `traces_service_graph_*`
series, which is what the APM dashboard queries.

A dummy loader (`ui/loader/`) does real HTTP work against every backend and is
instrumented with the OpenTelemetry SDK, so it appears in the stack it exercises:
`dojo-loader` spans become spanmetrics in Tempo, `loader_*` metrics land in
Mimir, and its log records land in Loki. It is a demonstration loader, not a
benchmark — one cycle every three seconds — and it deliberately injects the
problems the last exercise asks you to find:

| Injected | How it shows up |
|---|---|
| `mimir_bad_query`, `tempo_unknown_route`, `grafana_missing_dashboard`, `loki_bad_push` | failed spans (400/404), error counter, error ratio panel |
| `slow_backend` with `loader.simulated_delay_seconds` | p95 latency spike, `loader_slo_breaches_total` |
| healthy cycles | the baseline rate, latency and error floor |

Data comes from the same sources the exercises describe: the collector tails the
dojo API server's Kubernetes Events (so a Pending pod's `FailedScheduling` line is
in Loki under that pod's name), `kube-state-metrics` talks to the same API server
(so `kube_*` series describe the real seed objects),
`node-exporter` reads the host, the collector scrapes itself for `otelcol_*`
series, and three `telemetrygen` containers push synthetic spans, metrics and
logs through the collector into Tempo, Mimir and Loki.

`make ui` recreates any service whose config under `ui/config/` changed (the
files are checksummed into an env var), so editing a Loki or Tempo config never
leaves a stale container behind.

```sh
make ui          # start everything (~1 GB of image pulls the first time)
make ui-status   # which endpoints answer
make ui-down     # stop and remove the volumes
```

The in-cluster Ingresses (`grafana.dojo.local`, `tempo.dojo.local`) are still the
objects to inspect in k9s — `:ing -n observability` — they are just not what
serves the browser here.

## See the finished capstone before doing it

`make target-state` applies the reference manifests for exercises 17-20 to the
cluster — the built pipeline, the LGTM wiring, the generators, the cluster
exporters and the dashboard ConfigMap — plus `target/loader.yaml`, the same
instrumented dummy loader the live stack runs. On a real cluster that image has
to be built and pushed first (`podman build -t <registry>/k9s-dojo-loader
ui/loader`); no kubelet here will pull it.

It is an answer key for the *cluster*, not for the exercises: your answer files
and your manifests stay exactly as they were, so `make check` keeps grading your
work.

```sh
make target-state        # build the end state, print the inspection tour
make tui                 # :pods -n pipeline, :sts -n observability, :cm, :ing
make ui                  # the same state, with live dashboards
make target-state-clear  # remove the namespace and free the volumes
```

## Tearing down

| Target | Removes | Keeps |
|---|---|---|
| `make ui-down` | the live LGTM containers, network and volumes | clusters, kubeconfigs, progress |
| `make teardown` | the two kwok clusters and their kubeconfigs | the live UIs, the repository |
| `make destroy` | everything temporary: UIs, both clusters, any stray `dojo-*` cluster, `.dojo/` state | the repository — answers, manifests and progress files stay on disk |

`make destroy --images`-style image cleanup is available through the script
itself (`bin/destroy --images`) for reclaiming the ~1 GB the UI stack pulls.

## Customisation

Everything under `k9s-config/` is fed to k9s through `K9S_CONFIG_DIR`, so
exercises 14-16 can be done without touching `~/.config/k9s`:

```sh
make tui            # K9S_CONFIG_DIR=$PWD/k9s-config k9s --context aks-dojo-dev
```

`make tui CTX=aks-dojo-prod` opens k9s on the other cluster.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `make check` says "no cluster reachable" | `make setup` never ran, or `make reset` is still going |
| `:ctx` shows `kwok-dojo-…` contexts | kubeconfig merged before the cleanup ran; `make reset` |
| broken workloads look Healthy | the fault watcher died: `make reset` |
| `no such exercise: 5` | ids are two digits: `make check N=05` |
| plugins or skins do nothing | k9s was started without `make tui`, so `K9S_CONFIG_DIR` is unset |
| claims in exercise 17 stay Pending | `storageClassName` is not `manual`, so no static PV can match |
| exercise 18 says the collector has no config | the `pipeline` namespace is missing: `make apply N=17` first |
| an exporter endpoint in exercise 18 fails | service DNS is `<svc>.<ns>.svc.cluster.local`, and Loki needs `/otlp` on the path |
| `node-agent` pods cover only one node | the DaemonSet is missing the `CriticalAddonsOnly` toleration |
| kube-state-metrics is in `CrashLoopBackOff`/forbidden on a real cluster | the ClusterRole lacks `list`/`watch` on the resource it asks for |
| exercise 19 says a generator container is missing | `deploy/synthetic-load` needs three containers, one per telemetry signal |
| a dashboard never appears in Grafana | its ConfigMap lacks the `grafana_dashboard: "1"` label the sidecar watches |
| Grafana shows no dashboards at all | `grafana-dashboard-provider` is missing, so the file provider has no path |
