# Marketplace submission

Pre-filled answers for the submission issue at
https://github.com/omacom/omarchy-plugin-marketplace/issues/new?template=submit-plugin.yml

**Repository URL**
```
https://github.com/SmoothPixels/glyph-workspaces
```

**Category**
```
Compositor
```

**Tags** (max 3)
```
Bar, Workspaces, Quickshell
```

**Suggest a missing tag**
_(leave blank)_

**Maintainer notes**
```
Replaces omarchy.workspaces with four styles: Pac-Man (he walks to the
workspace you switch to and eats the pellets on the way), Dots, Numbers,
and Custom glyphs. Clicking a workspace switches to it via the same
hyprctl dispatch the built-in widget uses. No install hooks, no network
access, no sudo, no runtime dependencies beyond Omarchy itself.

omarchy.workspaces is a bar widget and nothing else, so the README's
install step disables it outright and the remove step re-enables it.
Nothing else about the bar is touched.

Pac-Man and the ghost are drawn on a Canvas rather than set from the Nerd
Fonts pacman glyph, which is a single fixed shape with no mouth animation
and no way to face left. They are a single fill colour, so they follow the
active theme like every other mark in the bar.

Also ships an optional "Style > Menu Bar > Workspace Style" submenu (a real
point-and-click picker, since there is no settings-form GUI yet). It is
opt-in only: a bundled script the user runs themselves splices it into
their own extensions/omarchy-menu.jsonc. Nothing runs automatically on
install.
```

**Submission checklist**
- [x] The repository is public and contains installation and removal instructions.
- [x] I have documented the plugin license and any external dependencies.
- [x] I confirm that I own or have permission to submit this plugin and its preview assets.
- [x] The plugin does not overwrite user configuration without explicit consent.
- [x] I understand that approval is for listing and is not a security review.
