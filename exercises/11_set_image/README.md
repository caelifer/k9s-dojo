# 11 — Set image on a running pod

`<i>` is k9s's image changer: it rewrites the container image field and lets the
kubelet restart the container. It exists for the case where you want one pod on
a new image *now*, without a rollout — a debugging move, not a release process.

| Key | Effect |
|---|---|
| `<i>` | Set Image on the selected pod/container |
| `<e>` | edit the whole object instead |
| `<r>` (deployments) | restart the rollout cleanly |

A pod's image is mutable; a Deployment's template is what you should normally
change, because that is what survives the next rescheduling. Exercise 10 was
the rollout way, this is the hammer.

## Your task

`aks-dojo-dev`, namespace `shop`:

1. `:pod`, filter to the redis pod (`/redis`), press `<i>`.
2. Type `redis:7.4-alpine` and confirm.
3. Watch the pod: k9s marks the container as restarted. `<y>` shows the new
   image in the pod spec.

Fill in `answer.txt`, then `make check`.
