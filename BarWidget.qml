pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Hyprland
import qs.Commons
import qs.Ui
import "Styles.js" as Styles

BarWidget {
  id: root
  moduleName: "io.github.smoothpixels.glyph-workspaces"

  // ------------------------------------------------------------------ settings
  // `omarchy bar set` stores values as JSON strings unless --json is passed,
  // so "5" and "true" are what actually reach shell.json. Coerce on read
  // rather than trusting the manifest's declared type, otherwise every
  // numeric and boolean setting only works when the user remembers --json.
  function numberSetting(name, fallback) {
    var value = setting(name, fallback)
    var parsed = typeof value === "number" ? value : parseFloat(value)
    return isNaN(parsed) ? fallback : parsed
  }

  function boolSetting(name, fallback) {
    var value = setting(name, fallback)
    if (typeof value === "boolean") return value
    if (typeof value === "string") return value === "true" || value === "1" || value === "yes"
    return fallback
  }

  // `ghost` began life as a boolean and is now a count. Reading true as 1
  // keeps every config written against the old meaning working unchanged.
  function countSetting(name, fallback) {
    var value = setting(name, fallback)
    if (value === true || value === "true") return 1
    if (value === false || value === "false") return 0
    var parsed = typeof value === "number" ? value : parseFloat(value)
    return isNaN(parsed) ? fallback : parsed
  }

  readonly property string style: setting("style", "pacman")
  readonly property int count: Math.max(1, Math.min(10, Math.round(numberSetting("count", 5))))
  readonly property string activeGlyph: setting("activeGlyph", Styles.MARKERS.powerPellet)
  readonly property string inactiveGlyph: setting("inactiveGlyph", Styles.MARKERS.ring)
  readonly property string focusedGlyph: setting("focusedGlyph", "")
  readonly property string indicator: setting("indicator", "auto")
  readonly property string urgentMode: setting("urgent", "flash")
  readonly property real dim: Math.max(0, Math.min(100, numberSetting("dim", 50))) / 100
  readonly property real fontSizeSetting: numberSetting("fontSize", 0)
  readonly property real slotWidthSetting: numberSetting("slotWidth", 0)
  readonly property string chomp: setting("chomp", "travel")
  readonly property real speed: Math.max(25, Math.min(400, numberSetting("speed", 100))) / 100
  readonly property bool eat: boolSetting("eat", true)
  readonly property bool sizeByWindows: boolSetting("sizeByWindows", true)
  readonly property int ghosts: Math.max(0, Math.min(4, Math.round(countSetting("ghost", 0))))
  readonly property int trail: Math.max(0, Math.min(6, Math.round(numberSetting("trail", 3))))
  readonly property bool scrollToSwitch: boolSetting("scroll", false)

  // Which styles put a character on the track, and which of those clear the
  // markers they pass. Both live in Styles.js so the catalog stays the one
  // place a new style has to be described.
  readonly property bool hasTraveller: Styles.hasTraveller(root.style)
  readonly property bool clearsMarkers: root.eat && Styles.clearsMarkers(root.style)

  // A character already says where you are, so `auto` leaves those styles
  // alone and underlines the rest.
  readonly property string indicatorMode: root.indicator === "auto"
    ? (root.hasTraveller ? "none" : "underline")
    : root.indicator

  function resolveColor(value, fallback) {
    if (value === "") return fallback
    if (value === "accent") return Color.accent
    if (value === "urgent") return Color.urgent
    if (value === "muted") return Color.muted
    return value
  }

  readonly property color baseColor: resolveColor(setting("color", ""),
    root.bar ? root.bar.barForeground : Color.foreground)
  // The character and the focused marker share this, so a pinned colour can
  // never leave them drifting apart on a theme change.
  readonly property color activeColor: resolveColor(setting("activeColor", ""), root.baseColor)
  readonly property string frightenedColorSetting: setting("frightenedColor", "")

  // --------------------------------------------------------------- workspaces
  function workspaceById(id) {
    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      if (values[i].id === id) return values[i]
    }

    return null
  }

  // Always show `count` workspaces, plus any live one above that, up to 10.
  function workspaceIds() {
    var ids = []
    for (var n = 1; n <= root.count; n++) ids.push(n)

    var values = Hyprland.workspaces.values
    for (var i = 0; i < values.length; i++) {
      var id = values[i].id
      if (id > 0 && id <= 10 && ids.indexOf(id) === -1) ids.push(id)
    }

    ids.sort(function(left, right) { return left - right })
    return ids
  }

  function focusWorkspace(id) {
    if (!root.bar) return
    root.bar.run("hyprctl dispatch " + Util.shellQuote("hl.dsp.focus({ workspace = \"" + id + "\" })"))
  }

  function step(delta) {
    var list = root.ids
    if (list.length === 0) return
    var current = root.focusedIndex < 0 ? 0 : root.focusedIndex
    var next = Math.max(0, Math.min(list.length - 1, current + delta))
    if (next !== current) root.focusWorkspace(list[next])
  }

  readonly property var ids: workspaceIds()
  readonly property int slotCount: ids.length
  readonly property int focusedId: Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : -1
  readonly property int focusedIndex: {
    var list = root.ids
    for (var i = 0; i < list.length; i++) {
      if (list[i] === root.focusedId) return i
    }
    return -1
  }

  // ----------------------------------------------------------------- geometry
  // Slot centres are computed arithmetically instead of read back off a
  // layout, because a travelling character has to address positions *between*
  // slots. One formula for both keeps it on the markers at every bar size.
  readonly property real slotLength: {
    if (root.slotWidthSetting > 0) return Style.space(root.slotWidthSetting)
    if (root.vertical) return root.barSize
    return Style.space(Styles.styleSlot(root.style, 16))
  }
  readonly property real gap: root.vertical ? Style.space(2) : Style.space(1)
  readonly property real trailingGap: root.vertical ? 0 : Style.spaceReal(1.5)
  readonly property real trackLength: root.slotCount * root.slotLength
    + Math.max(0, root.slotCount - 1) * root.gap
  readonly property real markerFontSize: root.fontSizeSetting > 0 ? root.fontSizeSetting : Style.font.body
  readonly property real charSize: Math.round(root.markerFontSize * 1.3)

  function slotPos(index) { return index * (root.slotLength + root.gap) }
  function slotCenter(index) { return index * (root.slotLength + root.gap) + root.slotLength / 2 }

  // Cross-axis centre for a character of the given size.
  function crossFor(size) { return (root.barSize - size) / 2 }

  // Where body segment `n` rides: half a slot behind the one ahead of it, on
  // the side the head came from, clamped so the tail cannot hang off the end
  // of the track.
  function trailSlot(n) {
    return Math.max(-0.25, Math.min(root.slotCount - 0.75,
      root.travelPos - root.facingSmooth * n * 0.5))
  }

  // Slots the snake's body is lying across. Without this a segment and the
  // marker underneath it stack up into one over-bright blob.
  function underTrail(index) {
    if (root.style !== "snake") return false
    for (var n = 1; n <= root.trail; n++) {
      if (Math.abs(root.trailSlot(n) - index) < 0.42) return true
    }
    return false
  }

  // More windows, bigger marker. The widget already reads the toplevel count
  // to decide occupied, so this is free information rather than new chrome -
  // and under Pac-Man it lands exactly on the metaphor: a busier workspace is
  // a fatter pellet. Numbers are left alone; scaled digits just look broken.
  function markerScale(windows, occupied) {
    if (!root.sizeByWindows || !occupied || root.style === "numbers") return 1
    return 1 + Math.min(windows, 5) * 0.09
  }

  implicitWidth: root.vertical ? root.barSize : root.trackLength + root.trailingGap
  implicitHeight: root.vertical ? root.trackLength : root.barSize

  // ------------------------------------------------------------- travel state
  // `travelPos` is a continuous slot index, not a pixel offset, so the same
  // number drives the character's x (or y) and the "have I passed this marker
  // yet" test. `travelTarget` is where it is headed, set the instant focus
  // moves, which is what the chasers and the cannon's shot animate towards.
  property real travelPos: 0
  property real travelTarget: 0
  property real shotPos: 0
  property real tripStart: 0
  property int travelDuration: 200
  // `tripDir` is the direction of the current trip and drives the marker
  // maths; `facing` is only which way the character is drawn. They part
  // company once it arrives: a trip leftwards still clears leftwards, but it
  // turns back to face right when it settles, the way Pac-Man does at the
  // start of an arcade life.
  property int tripDir: 1
  property int facing: 1
  // `facing` flips in one frame, which would snap the snake's body to the
  // other side of its head. This is the same flip eased out, so the body
  // swings round instead.
  property real facingSmooth: 1
  property bool hasSnapped: false
  property bool chaseShown: false
  property bool frightened: false

  Behavior on travelPos {
    enabled: root.hasSnapped
    NumberAnimation { id: travelAnim; duration: 200; easing.type: Easing.InOutQuad }
  }

  // The shot leaves before the cannon arrives, so it has to outrun it.
  Behavior on shotPos {
    enabled: root.hasSnapped
    NumberAnimation { id: shotAnim; duration: 120; easing.type: Easing.OutQuad }
  }

  function travelTo(index) {
    if (index < 0) return

    if (!root.hasSnapped) {
      root.tripStart = index
      root.travelPos = index
      root.travelTarget = index
      root.shotPos = index
      root.hasSnapped = true
      return
    }

    var distance = Math.abs(index - root.travelPos)
    if (distance < 0.001) return

    // Duration is read when the Behavior fires, so set it before assigning.
    root.travelDuration = Math.max(130, Math.round(distance * 190 / root.speed))
    travelAnim.duration = root.travelDuration
    shotAnim.duration = Math.max(90, Math.round(root.travelDuration * 0.55))

    root.tripDir = index > root.travelPos ? 1 : -1
    root.facing = root.tripDir
    root.tripStart = root.travelPos
    root.travelPos = index
    root.travelTarget = index
    root.shotPos = index

    respawnTimer.interval = root.travelDuration + 380
    respawnTimer.restart()

    // The chasers are only worth showing while there is a chase to see:
    // parked next to the character on a five-slot track they just sit on
    // top of a marker.
    root.chaseShown = true
    chaseHideTimer.interval = root.travelDuration + 300
    chaseHideTimer.restart()
  }

  // Power-pellet mode: clearing a marker on a workspace that was calling for
  // attention sends the ghosts harmless for a few seconds.
  function frighten() {
    root.frightened = true
    frightenTimer.restart()
  }

  // Collapsing the trip to a point is what makes cleared markers come back: a
  // marker counts as cleared only while it lies between tripStart and
  // travelPos.
  Timer {
    id: respawnTimer
    interval: 600
    onTriggered: {
      root.tripStart = root.travelPos
      root.facing = 1
    }
  }

  Timer {
    id: chaseHideTimer
    interval: 600
    onTriggered: root.chaseShown = false
  }

  Timer {
    id: frightenTimer
    interval: 4500
    onTriggered: root.frightened = false
  }

  onFacingChanged: root.facingSmooth = root.facing

  Behavior on facingSmooth {
    enabled: root.hasSnapped
    NumberAnimation { duration: 170; easing.type: Easing.OutQuad }
  }

  onFocusedIndexChanged: root.travelTo(root.focusedIndex)
  Component.onCompleted: root.travelTo(root.focusedIndex)

  readonly property bool travelling: travelAnim.running
  readonly property bool chomping: root.chomp === "always"
    || (root.chomp === "travel" && root.travelling)
  readonly property int chompHalf: Math.max(60, Math.round(105 / root.speed))

  SequentialAnimation {
    running: root.style === "pacman" && root.chomping
    loops: Animation.Infinite
    NumberAnimation {
      target: pacman; property: "mouth"; from: 0.06; to: 1.0
      duration: root.chompHalf; easing.type: Easing.InOutSine
    }
    NumberAnimation {
      target: pacman; property: "mouth"; from: 1.0; to: 0.06
      duration: root.chompHalf; easing.type: Easing.InOutSine
    }
    // Stopping a loop leaves the mouth mid-bite; park it open instead.
    onRunningChanged: if (!running) pacman.mouth = 0.55
  }

  // Engine flicker, fast enough to read as a burn rather than a redraw glitch.
  SequentialAnimation {
    running: root.style === "rocket" && root.travelling
    loops: Animation.Infinite
    NumberAnimation { target: rocket; property: "thrust"; from: 0.55; to: 1.0; duration: 70 }
    NumberAnimation { target: rocket; property: "thrust"; from: 1.0; to: 0.55; duration: 70 }
    onRunningChanged: if (!running) rocket.thrust = 0
  }

  // -------------------------------------------------------------------- slots
  Repeater {
    model: root.ids

    WidgetButton {
      id: slot

      required property int index
      required property int modelData

      readonly property var workspace: root.workspaceById(modelData)
      readonly property int windows: workspace !== null ? workspace.toplevels.values.length : 0
      readonly property bool occupied: windows > 0
      readonly property bool focused: modelData === root.focusedId
      // Hyprland raises this when a window on the workspace asks for
      // attention. The built-in widget ignores it, so an app calling you back
      // from another workspace leaves no trace on the bar at all.
      //
      // `occupied` is not redundant. Quickshell keeps handing back a workspace
      // object after Hyprland has destroyed the workspace, and a stale one can
      // still read urgent: switching away from an empty workspace that had
      // been flagged left it blinking forever on a workspace that no longer
      // exists. Urgency means a window is asking for you, so requiring a
      // window is both the fix and the honest condition.
      readonly property bool calling: root.urgentMode !== "none"
        && workspace !== null && workspace.urgent && occupied
      readonly property bool urgent: calling && !focused
      property bool blinkOn: true
      // Under the character right now.
      readonly property bool covered: root.hasTraveller
        && root.focusedIndex >= 0
        && (Math.abs(root.travelPos - index) < 0.42 || root.underTrail(index))
      // Passed on this trip, and not yet respawned.
      readonly property bool cleared: root.clearsMarkers
        && (index - root.tripStart) * root.tripDir > 0.001
        && (root.travelPos - index) * root.tripDir > -0.2

      bar: root.bar
      x: root.vertical ? 0 : root.slotPos(index)
      y: root.vertical ? root.slotPos(index) : 0
      fixedWidth: root.vertical ? root.barSize : root.slotLength
      fixedHeight: root.vertical ? root.slotLength : root.barSize
      text: Styles.markerFor(root.style, {
        id: modelData,
        occupied: occupied,
        focused: focused,
        activeGlyph: root.activeGlyph,
        inactiveGlyph: root.inactiveGlyph,
        focusedGlyph: root.focusedGlyph
      })
      fontSize: root.markerFontSize * root.markerScale(windows, occupied)
      foreground: focused && !root.hasTraveller ? root.activeColor : root.baseColor
      // WidgetButton paints `activeColor`, the bar's own urgent colour, while
      // this is true, and cross-fades back when it goes false.
      active: urgent && (root.urgentMode === "color" || blinkOn)
      opacity: covered || cleared ? 0 : (occupied || focused || urgent ? 1 : root.dim)
      horizontalMargin: 0
      verticalPadding: 6
      // Numbers say which workspace they are; markers do not.
      tooltipText: root.style === "numbers" ? "" : "Workspace " + modelData

      // Eating the marker on a workspace that was calling for attention is
      // the power pellet.
      onClearedChanged: if (cleared && calling) root.frighten()

      Timer {
        running: slot.urgent && root.urgentMode === "flash"
        interval: 520
        repeat: true
        onTriggered: slot.blinkOn = !slot.blinkOn
        onRunningChanged: if (!running) slot.blinkOn = true
      }

      onPressed: function(button) { root.focusWorkspace(modelData) }
      onWheelMoved: function(delta) { if (root.scrollToSwitch) root.step(delta > 0 ? -1 : 1) }
    }
  }

  // ---------------------------------------------------------------- indicator
  // A sliding mark on the focused slot. A travelling character already says
  // where you are, so `auto` only draws this for the other styles, but it is
  // available for all of them: the marker glyphs alone do not survive a theme
  // whose accent matches its foreground.
  Rectangle {
    id: indicator

    readonly property bool pill: root.indicatorMode === "pill"
    readonly property real thickness: pill ? root.barSize - Style.spaceReal(10) : Math.max(2, Math.round(root.barSize / 14))
    readonly property real length: pill ? root.slotLength : Math.round(root.slotLength * 0.55)

    visible: root.indicatorMode !== "none" && root.focusedIndex >= 0
    z: pill ? -1 : 0
    color: pill
      ? Qt.rgba(root.activeColor.r, root.activeColor.g, root.activeColor.b, 0.16)
      : root.activeColor
    radius: pill ? Math.round(thickness / 3) : thickness / 2

    width: root.vertical ? thickness : length
    height: root.vertical ? length : thickness
    x: root.vertical
      ? (pill ? (root.barSize - width) / 2 : Style.spaceReal(3))
      : root.slotCenter(root.focusedIndex) - width / 2
    y: root.vertical
      ? root.slotCenter(root.focusedIndex) - height / 2
      : (pill ? (root.barSize - height) / 2 : root.barSize - height - Style.spaceReal(5))

    Behavior on x { enabled: root.hasSnapped && !root.vertical; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
    Behavior on y { enabled: root.hasSnapped && root.vertical; NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
  }

  // ----------------------------------------------------------------- the cast
  // Declared after the Repeater so they stack above the markers.

  // The snake's body: tapering segments half a slot apart, close enough that
  // they overlap into one continuous body.
  //
  // This started out sitting on the workspaces you had most recently left, so
  // the tail doubled as a history of where you had been. That does not
  // survive the geometry: workspace history is not contiguous - the head can
  // be on 1 having come from 4 - so the body was either disconnected blobs,
  // which read as debris, or joined across the gaps, which covered the whole
  // track and hid every marker behind it. A snake that trails its own head is
  // the thing that actually reads as a snake on a five-slot bar.
  //
  // Each segment lags a little more than the one ahead, so the body whips
  // round behind the head on a turn instead of switching sides in one frame.
  Repeater {
    model: root.style === "snake" ? root.trail : 0

    Rectangle {
      id: segment
      required property int index

      readonly property real taper: 1 - (index + 1) * 0.13
      readonly property real thickness: Math.max(2, root.charSize * 0.72 * taper)

      readonly property real slot: root.trailSlot(index + 1)

      width: thickness
      height: thickness
      radius: thickness / 2
      color: root.baseColor
      opacity: 0.92 * taper
      x: root.vertical ? root.crossFor(thickness) : root.slotCenter(slot) - thickness / 2
      y: root.vertical ? root.slotCenter(slot) - thickness / 2 : root.crossFor(thickness)
    }
  }

  // The ghosts. Each sets off later than the one before, so the lag alone
  // strings them out into a chase - no per-ghost offset to keep in sync.
  Repeater {
    model: root.style === "pacman" ? root.ghosts : 0

    Ghost {
      id: chaser
      required property int index

      property real pos: root.travelTarget

      width: root.charSize * 0.92
      height: root.charSize * 0.92
      frightened: root.frightened
      color: root.frightened && root.frightenedColorSetting !== ""
        ? root.resolveColor(root.frightenedColorSetting, root.baseColor)
        : root.baseColor
      opacity: root.chaseShown || root.frightened ? 0.62 : 0
      look: root.vertical ? 0 : root.facing
      x: root.vertical ? root.crossFor(width) : root.slotCenter(pos) - width / 2
      y: root.vertical ? root.slotCenter(pos) - height / 2 : root.crossFor(height)

      Behavior on pos {
        enabled: root.hasSnapped
        SequentialAnimation {
          PauseAnimation { duration: 120 + chaser.index * 85 }
          NumberAnimation { duration: root.travelDuration; easing.type: Easing.InOutQuad }
        }
      }
      Behavior on opacity { NumberAnimation { duration: 220 } }
    }
  }

  // The cannon's shot, outrunning it to the target.
  Rectangle {
    id: shot
    visible: root.style === "invaders" && root.travelling
    width: root.vertical ? Math.max(3, root.charSize * 0.30) : Math.max(2, root.charSize * 0.12)
    height: root.vertical ? Math.max(2, root.charSize * 0.12) : Math.max(3, root.charSize * 0.30)
    radius: Math.min(width, height) / 2
    color: root.activeColor
    x: root.vertical ? root.crossFor(width) : root.slotCenter(root.shotPos) - width / 2
    y: root.vertical ? root.slotCenter(root.shotPos) - height / 2 : root.barSize * 0.22
  }

  Pacman {
    id: pacman
    visible: root.style === "pacman" && root.focusedIndex >= 0
    width: root.charSize
    height: root.charSize
    color: root.activeColor
    rotation: root.vertical ? (root.facing >= 0 ? 90 : 270) : (root.facing >= 0 ? 0 : 180)
    x: root.vertical ? root.crossFor(width) : root.slotCenter(root.travelPos) - width / 2
    y: root.vertical ? root.slotCenter(root.travelPos) - height / 2 : root.crossFor(height)

    Behavior on rotation { NumberAnimation { duration: 110 } }
  }

  SnakeHead {
    id: snakeHead
    visible: root.style === "snake" && root.focusedIndex >= 0
    width: root.charSize
    height: root.charSize
    color: root.activeColor
    rotation: root.vertical ? (root.facing >= 0 ? 90 : 270) : (root.facing >= 0 ? 0 : 180)
    x: root.vertical ? root.crossFor(width) : root.slotCenter(root.travelPos) - width / 2
    y: root.vertical ? root.slotCenter(root.travelPos) - height / 2 : root.crossFor(height)

    Behavior on rotation { NumberAnimation { duration: 110 } }
  }

  Rocket {
    id: rocket
    visible: root.style === "rocket" && root.focusedIndex >= 0
    width: root.charSize
    height: root.charSize
    color: root.activeColor
    rotation: root.vertical ? (root.facing >= 0 ? 90 : 270) : (root.facing >= 0 ? 0 : 180)
    x: root.vertical ? root.crossFor(width) : root.slotCenter(root.travelPos) - width / 2
    y: root.vertical ? root.slotCenter(root.travelPos) - height / 2 : root.crossFor(height)

    Behavior on rotation { NumberAnimation { duration: 110 } }
  }

  Cannon {
    id: cannon
    visible: root.style === "invaders" && root.focusedIndex >= 0
    width: root.charSize
    height: root.charSize
    color: root.activeColor
    x: root.vertical ? root.crossFor(width) : root.slotCenter(root.travelPos) - width / 2
    y: root.vertical ? root.slotCenter(root.travelPos) - height / 2 : root.crossFor(height)
  }
}
