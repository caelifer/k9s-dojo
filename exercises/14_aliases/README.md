# 14 — Aliases: your own command-mode names

Command mode is a text field, and k9s abbreviates the resource names for you.
`k9s-config/aliases.yaml` — which `make tui` feeds in through `K9S_CONFIG_DIR` —
is where you add your own.

```yaml
aliases:
  pp: pods          # already there
  rq: resourcequotas
```

The mapping is `alias: resource`, and the alias then works anywhere a resource
name does: `:rq`, `:rq shop`, and inside custom views.

| Where | What it is |
|---|---|
| `k9s-config/aliases.yaml` | command-mode aliases (this exercise) |
| `k9s-config/views.yaml` | custom column layouts |
| `k9s-config/config.yaml` | everything else, including the active skin |

`k9s info` prints which files k9s actually read; with the repo's config dir it
should point inside this repository, not at `~/.config/k9s`.

## Your task

Edit `k9s-config/aliases.yaml` and add two aliases:

| Alias | Resource |
|---|---|
| `rq` | `resourcequotas` |
| `lr` | `limitranges` |

Then restart k9s (`make tui`) and check that `:rq` and `:lr` open those views in
`shop`. Fill in `answer.txt`, then `make check`.
