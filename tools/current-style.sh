#!/bin/bash
# Prints the current "style" setting for io.github.smoothpixels.glyph-workspaces.
# Used by the Style > Menu Bar > Workspace Style menu rows (see
# extensions/omarchy-menu.snippet.jsonc) to tick the active choice.
set -euo pipefail

PLUGIN_ID="io.github.smoothpixels.glyph-workspaces"

find_style() {
  local file="$1"
  [[ -f $file ]] || return 1
  jq -r --arg id "$PLUGIN_ID" '
    [.bar.layout.left[]?, .bar.layout.center[]?, .bar.layout.right[]?]
    | map(select(.id == $id))
    | first
    | .style // empty
  ' "$file" 2>/dev/null
}

style=$(find_style "$HOME/.config/omarchy/shell.json" || true)
if [[ -z $style ]]; then
  style=$(find_style "${OMARCHY_PATH:-/usr/share/omarchy}/config/omarchy/shell.json" || true)
fi
echo "${style:-pacman}"
