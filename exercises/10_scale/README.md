# 10 — Editing: scale a deployment

k9s can write. `<e>` opens the selected object in `$EDITOR` as YAML; when the
editor exits, k9s shows the diff and applies it after you confirm. This is the
same path as `kubectl edit`, with the diff in front of you first.

| Key | Effect |
|---|---|
| `<e>` | edit the object as YAML |
| `<y>` | view the YAML without editing |
| `<ctrl-s>` | save, when you are in k9s's own YAML view |
| `<ctrl-d>` | delete (next exercise) |

Two habits worth forming now: read the header before editing (which cluster?)
and read the diff before accepting it.

## Your task

`aks-dojo-prod`, namespace `shop` — note the cluster, this changes production:

1. `:deploy`, select `frontend`, press `<e>`.
2. Change `replicas: 5` to `replicas: 7`. Save and quit the editor.
3. Accept the diff. The view should settle at `7/7`.
4. Press `<y>` on the deployment: satisfy yourself that the edit was a plain
   spec change, nothing else.

Fill in `answer.txt`, then `make check`.
