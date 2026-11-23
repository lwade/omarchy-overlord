#!/bin/bash
set -euo pipefail

root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

dest="$tmp/.config/omarchy/plugins/io.github.lwade.overlord"
mkdir -p "$dest/.git"
printf 'ref\n' > "$dest/.git/HEAD"

set +e
HOME="$tmp" "$root/scripts/install-dev" >"$tmp/out" 2>"$tmp/err"
code=$?
set -e

if [[ $code -eq 0 ]]; then
  echo "install-dev copied over a git checkout" >&2
  exit 1
fi
if [[ ! -f $dest/.git/HEAD ]]; then
  echo "install-dev removed .git" >&2
  exit 1
fi
if ! grep -q 'git checkout' "$tmp/err"; then
  echo "install-dev did not say why it refused" >&2
  cat "$tmp/err" >&2
  exit 1
fi

echo "install-dev ok"
