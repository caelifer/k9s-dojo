# 06 — Reading a broken workload

Three `shop` workloads are unhappy, for three reasons. The STATUS column is the
summary; the reason is one keypress away.

| Key | Shows |
|---|---|
| `<d>` | describe: spec, conditions, and the event stream at the bottom |
| `<y>` | the object as YAML |
| `<l>` | logs of the selected container |
| `<p>` | logs of the previous container — the one that already died |
| `<enter>` | drill into children (Deployment → pods) |

`<l>` and `<p>` need a real kubelet. On the simulated kwok cluster there is no
container to read from and k9s prints the API error verbatim; on your own AKS
cluster they show live container output.

## Your task

`aks-dojo-dev`, namespace `shop`, `:pod`:

1. `checkout-api` pods — what is the STATUS?
2. `worker` — STATUS, and how many RESTARTS?
3. `batch-renderer` — STATUS?
4. `batch-renderer` is unschedulable. `<d>` it: how much memory does its
   container request?

Fill in `answer.txt`, then `make check`.
