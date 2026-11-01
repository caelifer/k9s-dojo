# 12 — Delete a pod, watch the owner replace it

Deleting a pod is not deleting a workload. A Deployment keeps a ReplicaSet, the
ReplicaSet keeps the count, and a new pod appears within seconds. Knowing which
key does what — and which layer owns the pod — is what keeps this safe.

| Key | Effect |
|---|---|
| `<ctrl-d>` | delete the selected resource |
| `<ctrl-k>` | kill: delete with no grace period |
| `<shift-j>` | jump to the owner (pod → ReplicaSet → Deployment) |

`<ctrl-d>` never deletes a Deployment's pods for good: `spec.replicas` is
unchanged, so the ReplicaSet immediately creates a replacement. That is exactly
the "restart one pod" trick, and it is the cheapest way to test whether a new
pod comes up cleanly.

## Your task

`aks-dojo-dev`, namespace `shop`:

1. `:pod`, select one of the three `frontend` pods.
2. Note its name, then `<ctrl-d>` and confirm.
3. Watch the pod list: a new `frontend-…` pod appears with a new name.
4. `<shift-j>` on that pod to see who owns it.

Fill in `answer.txt`, then `make check`.
