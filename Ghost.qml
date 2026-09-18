import QtQuick

// The ghost that trails Pac-Man when `ghost` is on. Same reasoning as
// Pacman.qml: drawn, single fill colour, so it follows the theme.
//
// The eyes are punched out of the body with a destination-out composite
// rather than painted in the bar's background colour, so the ghost still
// reads correctly on a transparent bar.
Canvas {
  id: root

  property color color: "white"
  // -1 looks left, 0 straight ahead, 1 looks right.
  property real look: 0
  // Power-pellet state. The arcade turns the ghosts blue, which is not
  // available here: the bar has one themed foreground and no guaranteed
  // second colour, so a hard-coded blue would clash with half the themes.
  // Hollowing them out reads the same way - "these are not a threat now" -
  // and still follows the theme. Set `frightenedColor` if you want the blue.
  property bool frightened: false

  antialiasing: true
  renderStrategy: Canvas.Cooperative

  onColorChanged: requestPaint()
  onLookChanged: requestPaint()
  onFrightenedChanged: requestPaint()
  onWidthChanged: requestPaint()
  onHeightChanged: requestPaint()

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()

    var w = width
    var h = height
    if (w <= 0 || h <= 0) return

    var radius = w / 2
    var domeY = h * 0.08 + radius
    var skirtY = h * 0.80
    var bumps = 3
    var bumpWidth = w / bumps

    var stroke = Math.max(1, w * 0.10)
    ctx.fillStyle = root.color
    ctx.strokeStyle = root.color
    ctx.lineWidth = stroke
    ctx.lineJoin = "round"

    ctx.beginPath()
    ctx.arc(w / 2, domeY, radius, Math.PI, 0, false) // dome, left to right
    ctx.lineTo(w, skirtY)
    for (var i = 0; i < bumps; i++) {
      ctx.arc(w - bumpWidth / 2 - i * bumpWidth, skirtY, bumpWidth / 2, 0, Math.PI, false)
    }
    ctx.lineTo(0, domeY)
    ctx.closePath()
    if (root.frightened) ctx.stroke()
    else ctx.fill()

    // A hollow ghost has no fill to punch the eyes out of, so draw them.
    if (root.frightened) {
      ctx.beginPath()
      ctx.arc(w * 0.34, h * 0.42, Math.max(0.6, w * 0.07), 0, 2 * Math.PI, false)
      ctx.fill()
      ctx.beginPath()
      ctx.arc(w * 0.66, h * 0.42, Math.max(0.6, w * 0.07), 0, 2 * Math.PI, false)
      ctx.fill()
      return
    }

    var eyeRadius = w * 0.15
    var eyeY = h * 0.40
    var gaze = Math.max(-1, Math.min(1, root.look)) * w * 0.05
    ctx.globalCompositeOperation = "destination-out"
    ctx.beginPath()
    ctx.arc(w * 0.32 + gaze, eyeY, eyeRadius, 0, 2 * Math.PI, false)
    ctx.fill()
    ctx.beginPath()
    ctx.arc(w * 0.68 + gaze, eyeY, eyeRadius, 0, 2 * Math.PI, false)
    ctx.fill()
    ctx.globalCompositeOperation = "source-over"
  }
}
