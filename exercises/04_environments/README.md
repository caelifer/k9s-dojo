# 04 — Same app, two environments

The two clusters run the same base manifests with an environment overlay:

| | `aks-dojo-dev` | `aks-dojo-prod` |
|---|---|---|
| namespace `shop` | frontend ×3, plus a `frontend-canary` | frontend ×5 |
| extra namespace | — | `analytics` |
| nodes | 2 (system + 1 user) | 4 (system + 3 user) |

This is the everyday k9s job on Azure: one screen per cluster, compare, and be
sure which one you are looking at before pressing anything destructive. The
header's `Context:` line is the answer, and `:ctx` switches it.

`<enter>` on a Deployment drills into its pods; `<shift-j>` jumps from a pod to
its owner, which is how you get back up the chain (pod → ReplicaSet →
Deployment).

## Your task

1. In `aks-dojo-dev`: how many replicas does `frontend` want?
2. `:ctx`, switch to `aks-dojo-prod`, `:deploy -n shop`: how many now?
3. On prod, `:ns`: which namespace exists there and not on dev?
4. Back on dev, `:deploy`: which image runs the canary (`frontend-canary`)?

Fill in `answer.txt`, then `make check`.
