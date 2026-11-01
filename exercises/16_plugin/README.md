# 16 — Plugins: shell out from k9s

A plugin is a key that runs a command with the current selection baked in.
`k9s-config/plugins/dojo.yaml` is read because `make tui` sets
`K9S_CONFIG_DIR`; k9s merges it with its built-in plugins.

```yaml
plugins:
  dojo-batch:
    shortCut: Shift-B
    description: Batch pods in shop
    scopes:
      - pods
    command: kubectl
    background: false
    args:
      - get
      - pods
      - --namespace
      - shop
      - --selector
      - tier=batch
```

`scopes` decides which views show the key, `command` plus `args` is what runs,
and k9s substitutes `$NAMESPACE`, `$POD`, `$CONTEXT` and friends when you use
them. `background: true` runs it without taking over the screen.

This is how people bolt their own tools (`stern`, `kubectl neat`, `az aks
show`) onto the UI without leaving it.

## Your task

1. Create `k9s-config/plugins/dojo.yaml` with the plugin above.
2. Restart k9s, open `:pod` in `shop`, press `<shift-b>`: a second terminal pane
   shows the two batch pods.
3. Check that the same command works outside k9s — that is the real test of a
   plugin's argument list.

Fill in `answer.txt`, then `make check`.
