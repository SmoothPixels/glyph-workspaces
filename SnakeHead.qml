import QtQuick

// The snake's head. The body is drawn by the widget as capsules joining the
// slots the head has left, so only the head needs any detail.
//
// One eye, not two: at a 16px bar this is about eight pixels of head, and a
// pair of punched eyes turns to mush. A side-on head with a single eye and a
// flicked tongue reads as a snake instantly at that size.
//
// Always drawn facing right. The widget rotates the item.
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

    // Tongue, drawn first so the head covers where it enters the mouth.
    var tongueY = h * 0.5
    var tongueTip = w * 1.02
    ctx.lineWidth = Math.max(0.8, w * 0.055)
    ctx.strokeStyle = root.color
    ctx.beginPath()
    ctx.moveTo(w * 0.72, tongueY)
    ctx.lineTo(w * 0.94, tongueY)
    ctx.moveTo(w * 0.94, tongueY)
    ctx.lineTo(tongueTip, tongueY - h * 0.13)
    ctx.moveTo(w * 0.94, tongueY)
    ctx.lineTo(tongueTip, tongueY + h * 0.13)
    ctx.stroke()

    // Head: a blunt wedge, wider at the jaw than the snout.
    ctx.beginPath()
    ctx.ellipse(w * 0.04, h * 0.17, w * 0.80, h * 0.66)
    ctx.fill()

    // The single eye, set forward on the head.
    ctx.globalCompositeOperation = "destination-out"
    ctx.beginPath()
    ctx.arc(w * 0.56, h * 0.40, Math.max(0.7, w * 0.10), 0, 2 * Math.PI, false)
    ctx.fill()
    ctx.globalCompositeOperation = "source-over"
  }
}
