# 09 — RBAC: who may do it

Every API call is authorized. In k9s you can see the objects that decide it
without leaving the TUI, which is the fast way to answer "why is this service
account unable to list pods?".

| Command | Resource |
|---|---|
| `:sa` | ServiceAccounts |
| `:role`, `:rolebinding` | namespaced grants |
| `:clusterrole`, `:clusterrolebinding` | cluster-wide grants |
| `:rbac` | k9s view that groups the four together |

`<enter>` on a Role lists the rule; `<d>` prints the API verbs as written.
`<shift-j>` from a pod jumps to its owner; from a ServiceAccount it jumps to the
workload that uses it.

## Your task

In `aks-dojo-dev`, namespace `shop`:

1. Which ServiceAccount does `ops/metrics-agent` run as? (`:pod` → `<d>`, or
   `:sa` and look for the one the deployment references)
2. Which Role grants that account pod read access, and in which namespace?
3. What is the command-mode name for the combined RBAC view?

Fill in `answer.txt`, then `make check`.
