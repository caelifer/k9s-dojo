#!/usr/bin/env bash
# check.sh -- exercise 14: aliases
source "$(dirname "$0")/../../bin/lib.sh"

aliases_file="$DOJO_ROOT/k9s-config/aliases.yaml"

expect alias_name rq "the name you added"
expect alias_target resourcequotas "what it expands to"
expect_ci rq_works yes "it must open the quota view"

if [[ ! -r $aliases_file ]]; then
  _fail "k9s-config/aliases.yaml is missing"
else
  if python3 - "$aliases_file" <<'PY'
import sys, yaml
doc = yaml.safe_load(open(sys.argv[1])) or {}
aliases = doc.get("aliases") or {}
ok = aliases.get("rq") == "resourcequotas" and aliases.get("lr") == "limitranges"
sys.exit(0 if ok else 1)
PY
  then
    _ok
  else
    _fail "aliases.yaml must map rq -> resourcequotas and lr -> limitranges"
  fi
fi

kcheck "k9s reads this config dir" \
  bash -c "K9S_CONFIG_DIR=$DOJO_ROOT/k9s-config k9s info 2>/dev/null | grep -q '$DOJO_ROOT/k9s-config/aliases.yaml'"

finish
