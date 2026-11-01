# 01 — Orientation

k9s is a terminal front end for the Kubernetes API. Every row is a live API
response, refreshed every two seconds, and every action is a kubectl call with a
nicer face. There is no state to sync: kill the process and nothing is lost.

Start it against the dojo:

```sh
make tui
```

The header is the first thing to read: `Context:`, `Cluster:`, `User:`,
`K8s Rev:`. `CPU:` and `MEM:` are `n/a` here because the simulated node reports
no metrics.

| Key | What it does |
|---|---|
| `:` | command mode — jump to a resource or a command |
| `:ns` | the namespaces view |
| `:ctx` | the kubeconfig contexts view |
| `:pod`, `:deploy`, `:svc`, `:cm`, `:secret` | the usual resources |
| `<esc>` or `<q>` | back / clear |
| `<w>` | warp: pick the namespace you are looking at |
| `?` | the complete key map of your k9s build |

The screen has three bands: breadcrumb on top, table in the middle, the actions
that are valid for this view at the bottom.

## Your task

The dojo has two clusters (`aks-dojo-dev`, `aks-dojo-prod`) and three workload
namespaces (`shop`, `payments`, `ops`) in each.

1. `:ns` — how many namespaces carry the dojo workloads?
2. Which namespace owns the `ledger` deployment? `<enter>` on a namespace
   drills in, so you do not have to guess.
3. Find the command-mode entry that lists kubeconfig contexts (no colon).
4. From a resource view, which single key warps to another namespace?

Fill in `answer.txt`, then `make check`.
