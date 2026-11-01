# 03 — Views

A view is a table of one resource type. `:` plus a resource name switches; k9s
keeps history per view, so `<[>` and `<]>` walk back and forward.

| Command | Resource | Column worth watching |
|---|---|---|
| `:deploy` | Deployments | `READY` (ready/desired) |
| `:pod` | Pods | `STATUS`, `RESTARTS`, `AGE` |
| `:svc` | Services | `TYPE`, `CLUSTER-IP`, `PORT(S)` |
| `:cm` | ConfigMaps | `DATA` (key count) |
| `:secret` | Secrets | `TYPE`, `DATA` |

`<enter>` opens the row: on a Deployment that is its pods, on a Pod it is the
container log. `<d>` describe, `<y>` YAML — if you learn two keys, learn those.

Sorting is per view and survives the session: `<shift-n>` name, `<shift-a>` age,
`<shift-s>` status, `<shift-o>` the highlighted column.

## Your task

Stay in `aks-dojo-dev`, namespace `shop` (`<w>` or `:shop`).

1. `:deploy` — how many replicas does `frontend` want, and which image runs?
2. `:svc` — which Service exposes the shop outside the cluster, and on which
   node port?
3. `:svc` — which port does `redis` map to?

Fill in `answer.txt`, then `make check`.
