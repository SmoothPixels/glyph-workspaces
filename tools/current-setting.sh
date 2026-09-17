#!/bin/bash
# Prints one setting for io.github.smoothpixels.glyph-workspaces, falling back
# to the given default when the key is not in shell.json yet.
#   usage: current-setting.sh <key> <default>
# Used by the menu picker's toggle rows to tick the active state.
set -euo pipefail

PLUGIN_ID="io.github.smoothpixels.glyph-workspaces"
key="${1:?usage: current-setting.sh <key> <default>}"
fallback="${2:-}"

value=$(jq -r --arg id "$PLUGIN_ID" --arg key "$key" '
  [.bar.layout.left[]?, .bar.layout.center[]?, .bar.layout.right[]?]
  | map(select(.id == $id))
  | first
  | .[$key] // empty
  | tostring
' "$HOME/.config/omarchy/shell.json" 2>/dev/null || true)

echo "${value:-$fallback}"
