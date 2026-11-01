# 15 — Skins: restyle the UI

A skin is a YAML file of colours, and the file that selects it is
`k9s-config/config.yaml`. Skins are read from the `skins/` directory next to the
config, so `make tui` looks for `k9s-config/skins/<name>.yaml`.

```yaml
# k9s-config/skins/dojo.yaml
k9s:
  body:
    bgColor: "#1e1e2e"
    fgColor: "#cdd6f4"
  frame:
    border:
      fgColor: "#89b4fa"
```

```yaml
# k9s-config/config.yaml
k9s:
  ui:
    skin: dojo
```

`k9s --invert` flips a dark skin to a light one without editing it, which is
handy when you are mostly reading rather than typing.

## Your task

1. Create `k9s-config/skins/dojo.yaml` with a `k9s.body.bgColor` of `#1e1e2e`
   and a `k9s.body.fgColor` of `#cdd6f4`.
2. Point `k9s-config/config.yaml` at it: `k9s.ui.skin: dojo`.
3. Restart k9s and confirm the background changed — the header logo and the
   table body should both pick up the skin.

Fill in `answer.txt`, then `make check`.
