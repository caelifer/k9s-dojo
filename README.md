# k9s-dojo

Sixteen exercises for the [k9s](https://k9scli.io) terminal UI, built like
[ziglings](https://codeberg.org/ziglings/exercises): numbered exercises you edit,
a checker that refuses to pass until the work is actually done, and a throwaway
cluster that `make setup` builds for you.

The cluster is shaped like Azure AKS: two clusters in one kubeconfig, AKS-style
context and user names, agent pools with zones and instance types, an `MC_…`
resource group label on every node, AKS add-ons in `kube-system`, per-namespace
quotas and limit ranges, and three workloads that are broken on purpose.

## Prerequisites

| Tool | Why | Install |
|---|---|---|
| k9s | the thing you are learning | `sudo pacman -S k9s` |
| kubectl | seeding, live checks | `sudo pacman -S kubectl` |
| kwokctl | builds the two clusters without a container runtime | release binary, see below |
| python3 + PyYAML | cluster/kubeconfig plumbing | `sudo pacman -S python-yaml` |

kwokctl is a single binary:

```sh
curl -fsSLo /tmp/kwokctl \
  https://github.com/kubernetes-sigs/kwok/releases/download/v0.8.0/kwokctl-linux-amd64
install -m755 /tmp/kwokctl ~/.local/bin/kwokctl
```

No root, no Docker, no VM. `make setup` is idempotent and `make teardown`
removes both clusters.

## Quick start

```sh
make setup     # two clusters, seeded, in about 20 seconds
make tui       # k9s against aks-dojo-dev with this repo's config
make next      # which exercise is due
make check     # verify it
make list      # progress through all sixteen
```

## The cluster

| | `aks-dojo-dev` | `aks-dojo-prod` |
|---|---|---|
| Kubeconfig user | `clusterUser_rg-dojo-dev-weu_aks-dojo-dev` | `clusterUser_rg-dojo-prod-weu_aks-dojo-prod` |
| Namespaces | `shop`, `payments`, `ops` (+ cluster's own) | same + `analytics` |
| Node pools | systempool (D2s_v5, zone 1), userpool (D4s_v5, zone 1) | systempool + 3× D8s_v5, zones 1-3 |
| `shop` workloads | frontend ×3, frontend-canary, redis, checkout-api ×2, worker, batch-renderer | frontend ×5, redis, checkout-api ×2, worker, batch-renderer |
| Broken on purpose | checkout-api (ImagePullBackOff), worker (CrashLoopBackOff), batch-renderer (Pending/unschedulable) | same |

Everything else is normal Kubernetes: a ResourceQuota and LimitRange per
namespace, a ServiceAccount plus Role and RoleBinding in `shop`, coredns,
kube-proxy and csi-azuredisk-node in `kube-system`, one CronJob and one Job in
`payments`.

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
