# 13 — Filter, mark, and widen

Large namespaces are unreadable without filtering. k9s has three layers:
the view filter (`/`), the mark/select mechanism (`<space>`), and the column
set (`<ctrl-w>`). All three apply to whatever view you are in.

| Key | Effect |
|---|---|
| `/` | filter mode: fuzzy match against the visible rows |
| `<esc>` | clear the filter |
| `<space>` | mark the row, `<ctrl-\>` clears all marks |
| `<ctrl-w>` | toggle wide columns |
| `<shift-o>` | sort by the highlighted column |

Filter mode matches the rendered row text, so `/crash` finds the worker pod by
its status, and `/7.4` finds a pod by its image tag.

## Your task

`aks-dojo-dev`, namespace `shop`, `:pod`:

1. Which key enters filter mode?
2. Filter on `worker`: how many rows remain?
3. Clear the filter. Which key toggles the wide column set?
4. `<ctrl-w>` and `:pod`: which extra columns appear? (name two)

Fill in `answer.txt`, then `make check`.
