#!/usr/bin/env bash
# Put omarchy-herd on PATH and run its first-time setup.

set -euo pipefail

root=$(cd -- "$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")" && pwd)

mkdir -p "$HOME/.local/bin"
ln -sfn "$root/bin/omarchy-herd" "$HOME/.local/bin/omarchy-herd"

if [[ -d $root/plugin && -f $root/plugin/manifest.json ]]; then
  id=$(jq -r '.id' "$root/plugin/manifest.json")
  mkdir -p "$HOME/.config/omarchy/plugins"
  ln -sfn "$root/plugin" "$HOME/.config/omarchy/plugins/$id"

  # Put the Herd icon on the bar, next to the other status widgets.
  if command -v omarchy >/dev/null; then
    omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
    if ! omarchy plugin list --json 2>/dev/null | jq -e --arg id "$id" 'any(.[]; .id == $id and .enabled)' >/dev/null; then
      omarchy plugin enable "$id" --section right >/dev/null 2>&1 ||
        echo "Add the bar icon later with: omarchy plugin enable $id --section right"
    fi
  fi
fi

exec "$root/bin/omarchy-herd" setup
