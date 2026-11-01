# 07 — Quotas and default limits

AKS clusters usually have a `ResourceQuota` and a `LimitRange` per team
namespace. The quota caps what the whole namespace may request; the limit range
injects defaults into pods that do not declare their own. Both cause the same
kind of surprise: a rollout that fails with `Forbidden` instead of scheduling.

| Command | Resource | Look at |
|---|---|---|
| `:quota` | ResourceQuota | `USED` vs hard limits |
| `:limits` | LimitRange | `default` / `defaultRequest` columns |

`<d>` on a quota prints `hard` next to `used` per resource, which is the exact
comparison the API server makes when it rejects a create.

## Your task

In `aks-dojo-dev`, namespace `shop`:

1. `:quota` — how many pods may this namespace hold?
2. The same quota caps `requests.cpu`. What is that cap (plain number)?
3. `:limits` — what CPU limit does a container get when it declares none
   (250m-style)?
4. Which command-mode name opens the ResourceQuota view?

Fill in `answer.txt`, then `make check`.
