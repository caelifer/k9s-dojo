# 02 — Contexts: two clusters, two resource groups

A kubeconfig is a list of contexts. A context is a triple — cluster, user,
namespace — and switching context is switching cluster. On Azure this is how you
move between subscriptions and AKS clusters: you `az aks get-credentials` for
each one and the contexts pile up in one file.

The dojo ships exactly that shape, with the naming AKS itself writes:

| Context | Cluster | User |
|---|---|---|
| `aks-dojo-dev` | `aks-dojo-dev` | `clusterUser_rg-dojo-dev-weu_aks-dojo-dev` |
| `aks-dojo-prod` | `aks-dojo-prod` | `clusterUser_rg-dojo-prod-weu_aks-dojo-prod` |

The user name is `<kind>_<resource-group>_<cluster>`, which is how you can tell
two clusters apart when the context names are similar.

| Key | What it does |
|---|---|
| `:ctx` | contexts view: `<enter>` switches cluster |
| `?` header band | shows `Context`, `Cluster`, `User` for the active one |
| `<d>` on a node | its annotations carry the ARM resource id |

Azure identity lives on the objects, not in the API server:

- node label `kubernetes.azure.com/cluster` = `MC_<rg>_<cluster>_<region>`
- node annotation `aks.azure.com/arm-id` = the full
  `/subscriptions/<sub>/resourceGroups/...` path
- namespace label `dojo.azure/environment` = `workload` or `platform`

## Your task

In k9s:

1. `:ctx`. What user does the `aks-dojo-dev` context authenticate as?
2. Still in `:ctx`, which resource group does the prod context belong to?
3. Switch to `aks-dojo-dev` (`<enter>`), then `:no` for nodes. Pick a user-pool
   node and `<d>` it: which subscription id appears in the ARM id annotation?
4. What is the annotation key that carries that ARM id?

Fill in `answer.txt`, then `make check`.
