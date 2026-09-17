#!/bin/bash
# Opt-in: adds (or updates) a "Style > Menu Bar > Workspace Style" submenu in the
# Omarchy menu by splicing extensions/omarchy-menu.snippet.jsonc into the
# user's own ~/.config/omarchy/extensions/omarchy-menu.jsonc. Run this
# yourself, including again after updating the plugin; nothing in this
# plugin does it automatically (see README.md).
set -euo pipefail

PLUGIN_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SNIPPET="$PLUGIN_DIR/extensions/omarchy-menu.snippet.jsonc"
TARGET="$HOME/.config/omarchy/extensions/omarchy-menu.jsonc"
MARKER='"style.bar.workspaces'

[[ -f $SNIPPET ]] || { echo "Missing $SNIPPET, run tools/sync-menu.js first." >&2; exit 1; }

mkdir -p "$(dirname "$TARGET")"
if [[ ! -f $TARGET ]]; then
  printf '{\n}\n' > "$TARGET"
fi

# Drop any previously installed rows (every key from this plugin starts with
# the marker), then splice the current snippet back in. Running this again
# after `omarchy plugin update` is how existing installs pick up new glyphs.
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

grep -vF "$MARKER" "$TARGET" > "$tmp.stripped"
awk -v snippet="$SNIPPET" '
  /^}[[:space:]]*$/ && !done {
    while ((getline line < snippet) > 0) print line
    done = 1
  }
  { print }
' "$tmp.stripped" > "$tmp"
rm -f "$tmp.stripped"

mv "$tmp" "$TARGET"
trap - EXIT
chmod +x "$PLUGIN_DIR/tools/current-style.sh" "$PLUGIN_DIR/tools/current-setting.sh"

echo "Synced Style > Menu Bar > Workspace Style in $TARGET"
echo "The shell watches this file, so it should pick it up within a second or two."
