#!/usr/bin/env bash
# check.sh -- exercise 15: skin
source "$(dirname "$0")/../../bin/lib.sh"

skin_file="$DOJO_ROOT/k9s-config/skins/dojo.yaml"
config_file="$DOJO_ROOT/k9s-config/config.yaml"

expect skin_name dojo "the file is dojo.yaml"
expect_ci body_bg "#1e1e2e" "the background you set"
expect config_key k9s.ui.skin "where k9s reads the active skin"

if [[ ! -r $skin_file ]]; then
  _fail "k9s-config/skins/dojo.yaml is missing"
elif python3 - "$skin_file" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1])) or {}
body = ((doc.get("k9s") or {}).get("body") or {})
ok = str(body.get("bgColor", "")).lower() == "#1e1e2e" and \
     str(body.get("fgColor", "")).lower() == "#cdd6f4"
sys.exit(0 if ok else 1)
PY
then
  _ok
else
  _fail "dojo.yaml needs k9s.body.bgColor #1e1e2e and fgColor #cdd6f4"
fi

if [[ ! -r $config_file ]]; then
  _fail "k9s-config/config.yaml is missing"
elif python3 - "$config_file" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1])) or {}
ui = ((doc.get("k9s") or {}).get("ui") or {})
sys.exit(0 if ui.get("skin") == "dojo" else 1)
PY
then
  _ok
else
  _fail "config.yaml must set k9s.ui.skin: dojo"
fi

kcheck "k9s loads without a skin error" \
  bash -c "K9S_CONFIG_DIR=$DOJO_ROOT/k9s-config k9s info >/dev/null 2>&1"

finish
