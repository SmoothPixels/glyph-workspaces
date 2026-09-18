import QtQuick

// The Space Invaders cannon: a stepped base with a turret. Deliberately not
// rotated with travel direction, unlike the other characters - a cannon that
// tipped over to face left would stop reading as a cannon.
Canvas {
  id: root

  property color color: "white"

  antialiasing: true
  renderStrategy: Canvas.Cooperative

  onColorChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()

    var w = width
    var h = height
    if (w <= 0 || h <= 0) return

    ctx.fillStyle = root.color
    // Base.
    ctx.beginPath()
    ctx.rect(w * 0.06, h * 0.62, w * 0.88, h * 0.24)
    ctx.fill()
    // Shoulders.
    ctx.beginPath()
    ctx.rect(w * 0.24, h * 0.42, w * 0.52, h * 0.22)
    ctx.fill()
    // Turret.
    ctx.beginPath()
    ctx.rect(w * 0.44, h * 0.16, w * 0.12, h * 0.28)
    ctx.fill()
  }
}
