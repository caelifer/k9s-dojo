# 17 — Capstone: build and inspect an observability pipeline

Everything up to here was reading a cluster somebody else seeded. This one you
build, and then you inspect it live, the way you would on a real AKS cluster
after `helm install` of an observability pipeline.

The shape is the one Datadog's [Kubernetes observability
pipelines](https://www.datadoghq.com/architecture/observability-pipelines-kubernetes-deployment/)
reference deploys, reduced to plain YAML:

| Piece | Object | Why it is hard |
|---|---|---|
| collectors | StatefulSet, 2 replicas | stable identity per replica, one volume each |
| discovery | headless Service | no cluster IP, DNS per pod, endpoints for each replica |
| edge | Ingress + TLS | host, path, backend port, TLS secret |
| node coverage | DaemonSet | must tolerate the system-pool taint to see every node |
| capacity | HorizontalPodAutoscaler | targets a StatefulSet, not a Deployment |
| configuration | ConfigMap + Secret | mounted twice: read-only source, writable copy |

## 1. Build it

`manifests/` holds three files with `TODO` markers and one file that is already
complete:

```sh
kubectl --context aks-dojo-dev apply -f exercises/17_pipeline/manifests/
```

Start with `00-namespace.yaml` (namespace + secret), fill in
`10-collector.yaml`, `20-agent.yaml`, `30-ingress.yaml`, and re-apply until the
API server stops complaining. `make apply N=17` does the apply for you.

Watch it come up in k9s while you work: `:sts`, `:pods`, `:pvc`, `:ing`, `:hpa`,
`:ds`. A StatefulSet pod is `collector-0`, `collector-1` — ordinals, not hashes,
which is the visible difference from a Deployment.

Two facts about this cluster matter while you build:

- volumes bind because `storageClassName: manual` matches the static
  PersistentVolumes that already exist; a claim asking for another class stays
  Pending forever.
- there is no ingress controller, so the Ingress object is validated and listed
  but never gets an address. Its rules are still what you audit.

## 2. Inspect it

Stay on `aks-dojo-dev` and answer from the TUI:

1. `:pods -n pipeline` — how many collector pods, and what are their names?
2. `:pvc -n pipeline` — how many claims, and what state are they in?
3. `:svc -n pipeline` — which collector Service is headless (no cluster IP)?
4. `:ing -n pipeline` — which host does the collector Ingress route?
5. `:hpa` — what are the HPA's minimum and maximum replicas?
6. `:ds` — how many `node-agent` pods, and on which pools?
7. `<d>` on a collector pod — what is its init container called?

Fill in `answer.txt`, then `make check`. The checker lints your manifests with a
server-side dry run and then asserts the live objects, so a guess fails.
