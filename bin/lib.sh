#!/usr/bin/env bash
# bin/lib.sh -- shared helpers for exercise checkers.
#
# A checker sources this file and calls expect*/require* helpers; every helper
# records a failure instead of aborting, so one run reports every wrong line.

# shellcheck shell=bash

DOJO_ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
EX_DIR=${EX_DIR:-$PWD}

CHECK_FAILS=()
CHECK_COUNT=0

say() { printf '  %s\n' "$*"; }

# strip whitespace, surrounding quotes/backticks and trailing comments
normalize() {
  local v=${1-}
  v=$(printf '%s' "$v" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//' -e 's/[[:space:]]#.*$//')
  v=$(printf '%s' "$v" | sed -e 's/[[:space:]]*$//')
  v=${v#\"}; v=${v%\"}
  v=${v#\'}; v=${v%\'}
  v=${v#\`}; v=${v%\`}
  printf '%s' "$v"
}

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# answer_get KEY -> the value written after "KEY:" in answer.txt
answer_get() {
  local key=$1 file=$EX_DIR/answer.txt line
  [[ -r $file ]] || {
    printf ''
    return
  }
  line=$(awk -v k="$key:" 'index($0, k) == 1 { print; exit }' "$file")
  [[ -n $line ]] || {
    printf ''
    return
  }
  normalize "${line#*:}"
}

_fail() {
  CHECK_COUNT=$((CHECK_COUNT + 1))
  CHECK_FAILS+=("$1")
}

_ok() { CHECK_COUNT=$((CHECK_COUNT + 1)); }

# expect KEY EXPECTED [hint]
expect() {
  local key=$1 want=$2 hint=${3-} got
  got=$(answer_get "$key")
  if [[ -z $got ]]; then
    _fail "$key is empty in answer.txt${hint:+ (${hint})}"
  elif [[ $got != "$want" ]]; then
    _fail "$key is '$got', expected '$want'${hint:+ (${hint})}"
  else
    _ok
  fi
}

# expect_ci KEY EXPECTED -- same, ignoring case
expect_ci() {
  local key=$1 want=$2 hint=${3-} got
  want=$(lower "$want")
  got=$(lower "$(answer_get "$key")")
  if [[ -z $got ]]; then
    _fail "$key is empty in answer.txt${hint:+ (${hint})}"
  elif [[ $got != "$want" ]]; then
    _fail "$key is '$got', expected '$want'${hint:+ (${hint})}"
  else
    _ok
  fi
}

# expect_any KEY VALUE... -- accept any of the listed values, case-insensitively
expect_any() {
  local key=$1
  shift
  local got want ok=1
  got=$(lower "$(answer_get "$key")")
  if [[ -z $got ]]; then
    _fail "$key is empty in answer.txt"
    return
  fi
  for want in "$@"; do
    if [[ $got == "$(lower "$want")" ]]; then
      ok=0
      break
    fi
  done
  if ((ok)); then
    _fail "$key is '$got', expected one of: $*"
  else
    _ok
  fi
}

# expect_match KEY ERE -- value must match the extended regex
expect_match() {
  local key=$1 re=$2 got
  got=$(answer_get "$key")
  if [[ -z $got ]]; then
    _fail "$key is empty in answer.txt"
  elif ! [[ $got =~ $re ]]; then
    _fail "$key is '$got', expected to match /$re/"
  else
    _ok
  fi
}

# expect_text KEY SUBSTRING -- value must contain the substring, case-insensitively
expect_text() {
  local key=$1 sub=$2 got
  got=$(lower "$(answer_get "$key")")
  sub=$(lower "$sub")
  if [[ -z $got ]]; then
    _fail "$key is empty in answer.txt"
  elif [[ $got != *"$sub"* ]]; then
    _fail "$key is missing '$sub'"
  else
    _ok
  fi
}

# require_cluster -- skip the whole exercise when the API server is unreachable
require_cluster() {
  if ! kubectl cluster-info >/dev/null 2>&1; then
    printf '\n  no cluster reachable -- run `make setup` first\n\n'
    exit 2
  fi
}

# kcheck DESCRIPTION COMMAND... -- live assertion through kubectl
kcheck() {
  local desc=$1
  shift
  if "$@" >/dev/null 2>&1; then
    _ok
  else
    _fail "cluster state: $desc"
  fi
}

# finish -- print the verdict; exit status is what make sees
finish() {
  if ((${#CHECK_FAILS[@]})); then
    printf '\n'
    local f
    for f in "${CHECK_FAILS[@]}"; do
      printf '  FAIL  %s\n' "$f"
    done
    printf '\n  %d of %d checks failed. Read exercises/%s/README.md again.\n\n' \
      "${#CHECK_FAILS[@]}" "$CHECK_COUNT" "$(basename "$EX_DIR")"
    exit 1
  fi
  printf '\n  all %d checks passed\n\n' "$CHECK_COUNT"
  exit 0
}
