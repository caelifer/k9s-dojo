#!/usr/bin/env bash
# check.sh -- exercise 16: plugin
source "$(dirname "$0")/../../bin/lib.sh"

plugin_file="$DOJO_ROOT/k9s-config/plugins/dojo.yaml"

expect plugin_name dojo-batch "the entry name"
expect_ci plugin_shortcut Shift-B "the shortCut field"
expect plugin_pod_count 2 "worker and batch-renderer"

if [[ ! -r $plugin_file ]]; then
  _fail "k9s-config/plugins/dojo.yaml is missing"
elif python3 - "$plugin_file" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1])) or {}
plugin = (doc.get("plugins") or {}).get("dojo-batch") or {}
ok = (plugin.get("shortCut") == "Shift-B"
      and plugin.get("command") == "kubectl"
      and "pods" in (plugin.get("scopes") or [])
      and "tier=batch" in (plugin.get("args") or []))
sys.exit(0 if ok else 1)
PY
then
  _ok
else
  _fail "dojo.yaml needs dojo-batch with shortCut, scopes and kubectl args"
fi

require_cluster
kcheck "the plugin's command works outside k9s" \
  bash -c '[[ $(kubectl --context aks-dojo-dev get pods -n shop -l tier=batch \
    --no-headers | wc -l) == 2 ]]'

finish
