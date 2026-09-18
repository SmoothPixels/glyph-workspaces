import QtQuick

// A rocket, drawn for the same reason Pac-Man is: a font glyph is one fixed
// shape, and this one needs a thrust flame that only burns while it moves.
//
// Always drawn nose-right. The widget rotates the item to turn it around.
Canvas {
  id: root

  property color color: "white"
  // 0 is coasting, 1 is full burn. Flickers while travelling.
  property real thrust: 0

  antialiasing: true
  renderStrategy: Canvas.Cooperative

  onColorChanged: requestPaint()
  onThrustChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()

    var w = width
    var h = height
    if (w <= 0 || h <= 0) return

    var midY = h / 2
    var noseX = w * 0.97
    var bodyBack = w * 0.34
    var bodyHalf = h * 0.20

    ctx.fillStyle = root.color

    // Fins, drawn first so the body sits over their inner edge.
    ctx.beginPath()
    ctx.moveTo(bodyBack + w * 0.10, midY - bodyHalf)
    ctx.lineTo(bodyBack - w * 0.06, midY - h * 0.44)
    ctx.lineTo(bodyBack + w * 0.02, midY - bodyHalf * 0.2)
    ctx.closePath()
    ctx.fill()
    ctx.beginPath()
    ctx.moveTo(bodyBack + w * 0.10, midY + bodyHalf)
    ctx.lineTo(bodyBack - w * 0.06, midY + h * 0.44)
    ctx.lineTo(bodyBack + w * 0.02, midY + bodyHalf * 0.2)
    ctx.closePath()
    ctx.fill()

    // Body: a capsule back from the nose, with the nose drawn as a curve so
    // it stays a point rather than a triangle at small bar sizes.
    ctx.beginPath()
    ctx.moveTo(noseX, midY)
    ctx.quadraticCurveTo(w * 0.60, midY - bodyHalf, w * 0.44, midY - bodyHalf)
    ctx.lineTo(bodyBack, midY - bodyHalf)
    ctx.quadraticCurveTo(bodyBack - w * 0.08, midY, bodyBack, midY + bodyHalf)
    ctx.lineTo(w * 0.44, midY + bodyHalf)
    ctx.quadraticCurveTo(w * 0.60, midY + bodyHalf, noseX, midY)
    ctx.closePath()
    ctx.fill()

    var burn = Math.max(0, Math.min(1, root.thrust))
    if (burn <= 0.01) return

    // Flame: a tapered plume off the tail, length riding on `thrust` so the
    // flicker reads as an engine rather than as a redraw glitch.
    var tail = bodyBack - w * 0.03
    var plume = w * 0.30 * burn
    ctx.globalAlpha = 0.45 + 0.55 * burn
    ctx.beginPath()
    ctx.moveTo(tail, midY - bodyHalf * 0.62)
    ctx.quadraticCurveTo(tail - plume * 0.5, midY, tail - plume, midY)
    ctx.quadraticCurveTo(tail - plume * 0.5, midY, tail, midY + bodyHalf * 0.62)
    ctx.closePath()
    ctx.fill()
    ctx.globalAlpha = 1
  }
}
