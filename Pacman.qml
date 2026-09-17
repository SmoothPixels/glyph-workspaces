import QtQuick

// Pac-Man, drawn rather than set in a font.
//
// The Nerd Fonts pacman glyph exists, but it is a single fixed shape: no
// mouth animation and no way to face left. Drawing the wedge takes about as
// much code as resolving the codepoint would, keeps the mark crisp at any
// bar size, and leaves it a single fill colour, so it still follows the
// active theme the way every other glyph in the bar does.
//
// Always drawn facing right. The widget rotates the item to turn him around.
Canvas {
  id: root

  property color color: "white"
  // 0 is a closed mouth, 1 is the widest bite.
  property real mouth: 0.55
  // Half-angle of the widest bite, as a fraction of PI.
  property real maxBite: 0.31

  antialiasing: true
  renderStrategy: Canvas.Cooperative

  onMouthChanged: requestPaint()
  onColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()

    var cx = width / 2
    var cy = height / 2
    var radius = Math.min(width, height) / 2
    if (radius <= 0) return

    var bite = Math.max(0, Math.min(1, root.mouth)) * root.maxBite * Math.PI

    ctx.fillStyle = root.color
    ctx.beginPath()
    if (bite <= 0.001) {
      ctx.arc(cx, cy, radius, 0, 2 * Math.PI, false)
    } else {
      ctx.moveTo(cx, cy)
      ctx.arc(cx, cy, radius, bite, 2 * Math.PI - bite, false)
      ctx.closePath()
    }
    ctx.fill()
  }
}
