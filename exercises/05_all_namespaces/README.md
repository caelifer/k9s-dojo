# 05 — All namespaces at once

Every namespaced view can drop the namespace filter. That is what you want when
the question is "where is this thing?" rather than "what is in my namespace?".
On a shared AKS cluster this is how you find a workload that somebody else's
team deployed.

| Key | Effect |
|---|---|
| `0` | toggle all namespaces for the current view |
| `<ctrl-w>` | toggle wide columns |
| `<shift-n>` / `<shift-s>` | sort by name / status |
| `<w>` | go back to a single namespace |

The first column of an all-namespace view is `NAMESPACE`; in a namespaced view
that column disappears, which is a useful tell for which mode you are in.

## Your task

In `aks-dojo-dev`:

1. Which key switches a view to all namespaces?
2. `:deploy` with all namespaces on: which namespace holds the most
   Deployments?
3. `:deploy` in `kube-system`: how many replicas does `coredns` want, and what
   is the DaemonSet count (`:ds`) in that namespace?

Fill in `answer.txt`, then `make check`.
