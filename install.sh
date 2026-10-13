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
fi

exec "$root/bin/omarchy-herd" setup
