# 08 — Nodes, agent pools, zones

An AKS cluster is a set of node pools. Each node carries the pool name as a
label, the region and zone as topology labels, the VM size as instance type, and
the `MC_…` resource group as `kubernetes.azure.com/cluster`. This is what k9s's
node view is for, and it works the same against a real subscription.

| Key | Effect in `:no` |
|---|---|
| `<ctrl-w>` | wide columns: labels, taints, versions |
| `<shift-o>` | sort by the highlighted column |
| `<d>` | describe: allocatable, taints, conditions, ARM id |
| `<s>` | shell onto the node (needs a real kubelet) |

The dojo's `dev` cluster has two nodes: a `systempool` node tainted
`CriticalAddonsOnly` (only kube-system pods land there, because they tolerate
it) and one `userpool` node that runs everything else.

## Your task

`aks-dojo-dev`, `:no`:

1. How many nodes does dev have?
2. What is the user node's instance type?
3. Which zone is the system node in?
4. Which taint key protects the system pool from workload pods?
5. Which region are both nodes labelled with?

Fill in `answer.txt`, then `make check`.
