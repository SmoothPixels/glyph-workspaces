// Single source of truth for the widget's styles and its marker glyphs.
//
// Each style entry is { id, label, description, icon, slot }:
//   id          the enum value stored in settings
//   label       shown in the manifest dropdown, the README and the menu picker
//   description one line, used by the manifest schema and the menu row
//   icon        Nerd Font codepoint (hex) for the menu picker's icon column
//   slot        default along-axis slot size in Style.space() units, the
//               density that suits this style when `slotWidth` is 0
//
// Every codepoint below was checked against the real charset of
// JetBrainsMono Nerd Font (Omarchy's default) with fontconfig, not copied
// from a cheat sheet: a name in the Nerd Fonts index is not a promise that a
// patched font ships the glyph, and a missing one draws a tofu box rather
// than failing loudly. Roman numerals (U+2160..) were dropped as a style for
// exactly that reason - JetBrainsMono does not carry them.
//
// Run `node tools/sync-manifest.js && node tools/sync-menu.js` after editing.
function styles() {
  return [
    {
      id: "pacman",
      label: "Pac-Man",
      description: "Pac-Man travels to the focused workspace, eating the pellets on the way",
      icon: "f0baf",
      slot: 16
    },
    {
      id: "snake",
      label: "Snake",
      description: "A snake whose head is the focused workspace and whose body trails through the ones you came from",
      icon: "f150e",
      slot: 16
    },
    {
      id: "rocket",
      label: "Rocket",
      description: "A rocket that flies to the focused workspace, thrust pointing back the way it came",
      icon: "f135",
      slot: 16
    },
    {
      id: "invaders",
      label: "Space Invaders",
      description: "Occupied workspaces are invaders; a cannon slides to the focused one, shooting what it passes",
      icon: "f0bc9",
      slot: 16
    },
    {
      id: "dots",
      label: "Dots",
      description: "A filled dot per occupied workspace, a small one per empty workspace",
      icon: "f0765",
      slot: 14
    },
    {
      id: "numbers",
      label: "Numbers",
      description: "Workspace numbers, like the built-in widget",
      icon: "f292",
      slot: 20
    },
    {
      id: "glyph",
      label: "Custom glyphs",
      description: "Your own two characters, one for occupied workspaces and one for empty",
      icon: "f03e",
      slot: 14
    }
  ]
}

// Marker characters for the built-in styles. All four are in JetBrainsMono
// Nerd Font's charset; see the note above before swapping any of them.
var MARKERS = {
  powerPellet: "●", // BLACK CIRCLE, an occupied workspace
  pellet: "•",      // BULLET, an empty workspace
  ring: "○",        // WHITE CIRCLE, the default custom-glyph "empty"
  focus: "◉",       // FISHEYE, the focused workspace
  invader: "󰯉", // U+F0BC9 md-space-invaders, the Invaders marker
  // U+F14FB, what omarchy.workspaces puts on the focused slot in place of its
  // number. Written as the surrogate pair the built-in widget uses. Set it as
  // `focusedGlyph` to reproduce the stock look exactly; see the README.
  omarchyFocus: "󱓻"
}

// Styles that put a character on the track. They all share the travel
// machinery: one continuous slot index drives where the character is drawn
// and, for the ones that eat, which markers it has already passed.
function hasTraveller(style) {
  return style === "pacman" || style === "snake"
    || style === "rocket" || style === "invaders"
}

// ...and of those, the ones where passing a marker removes it. Pac-Man eats
// pellets; the cannon shoots invaders. The snake is trailing its own body
// through them and the rocket is only flying past, so neither clears a slot.
function clearsMarkers(style) {
  return style === "pacman" || style === "invaders"
}

function findStyle(id) {
  var list = styles()
  for (var i = 0; i < list.length; i++) {
    if (list[i].id === id) return list[i]
  }
  return null
}

function styleSlot(id, fallback) {
  var entry = findStyle(id)
  return entry ? entry.slot : fallback
}

function glyphChar(code) {
  return String.fromCodePoint(parseInt(code, 16))
}

// The text a single workspace slot paints, given its style and state.
//
// Focus is marked by shape, not only by colour: a theme is free to set the
// bar's accent to the same value as its foreground, and several do, so a
// colour-only focus cue can vanish entirely. The indicator the widget draws
// underneath is the other half of that, and works for `numbers` too.
//
// `pacman` returns pellets here as well. Pac-Man himself is drawn on top by
// the widget; the slots underneath stay ordinary pellets so they keep their
// click target and their occupied/empty meaning, and so they can be eaten.
function markerFor(style, state) {
  // A focused glyph, once set, replaces the focused marker in every text
  // style, not just the custom one: that is what lets `numbers` reproduce the
  // built-in widget, which swaps its focused number for a glyph. Not in
  // `pacman`, where the focused slot is a pellet he is standing on.
  if (style !== "pacman" && state.focused && state.focusedGlyph !== "") return state.focusedGlyph

  if (style === "numbers") return state.id === 10 ? "0" : String(state.id)
  if (style === "glyph") {
    if (state.focused) return state.activeGlyph
    return state.occupied ? state.activeGlyph : state.inactiveGlyph
  }
  // An invader per occupied workspace, a pellet per empty one, so the row
  // still reads as "which of these has windows" before it reads as a game.
  if (style === "invaders") return state.occupied ? MARKERS.invader : MARKERS.pellet
  if (style === "pacman" || style === "snake" || style === "rocket") {
    return state.occupied ? MARKERS.powerPellet : MARKERS.pellet
  }
  if (state.focused) return MARKERS.focus
  return state.occupied ? MARKERS.powerPellet : MARKERS.pellet
}

if (typeof module !== "undefined") {
  module.exports = {
    styles: styles,
    hasTraveller: hasTraveller,
    clearsMarkers: clearsMarkers,
    findStyle: findStyle,
    styleSlot: styleSlot,
    glyphChar: glyphChar,
    markerFor: markerFor,
    MARKERS: MARKERS
  }
}
