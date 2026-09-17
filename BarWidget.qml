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
  readonly property string indicatorMode: root.indicator === "auto"
    ? (root.style === "pacman" ? "none" : "underline")
    : root.indicator
  readonly property bool ghostEnabled: boolSetting("ghost", false)
  readonly property bool scrollToSwitch: boolSetting("scroll", false)

  function resolveColor(value, fallback) {
    if (value === "") return fallback
    if (value === "accent") return Color.accent
    if (value === "urgent") return Color.urgent
    if (value === "muted") return Color.muted
    return value
  }

  readonly property color baseColor: resolveColor(setting("color", ""),
    root.bar ? root.bar.barForeground : Color.foreground)
  // Pac-Man and the focused marker share this, so a pinned colour can never
  // leave the mark and the markers drifting apart on a theme change.
  readonly property color activeColor: resolveColor(setting("activeColor", ""), root.baseColor)

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
  // layout, because Pac-Man's travel has to address positions *between*
  // slots. One formula for both keeps him on the pellets at every bar size.
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
  readonly property real pacSize: Math.round(root.markerFontSize * 1.3)

  function slotPos(index) { return index * (root.slotLength + root.gap) }
  function slotCenter(index) { return index * (root.slotLength + root.gap) + root.slotLength / 2 }

  implicitWidth: root.vertical ? root.barSize : root.trackLength + root.trailingGap
  implicitHeight: root.vertical ? root.trackLength : root.barSize

  // ------------------------------------------------------------- travel state
  // `pacPos` is a continuous slot index, not a pixel offset, so the same
  // number drives his x (or y) and the "have I passed this pellet yet" test.
  property real pacPos: 0
  property real ghostPos: 0
  property real tripStart: 0
  // `tripDir` is the direction of the current trip and drives the pellet
  // maths; `facing` is only which way he is drawn. They part company once he
  // arrives: a trip leftwards still eats leftwards, but he turns back to face
  // right when he settles, the way he does at the start of an arcade life.
  property int tripDir: 1
  property int facing: 1
  property bool hasSnapped: false
  property bool ghostShown: false

  Behavior on pacPos {
    enabled: root.hasSnapped
    NumberAnimation { id: travelAnim; duration: 200; easing.type: Easing.InOutQuad }
  }

  // The pause is the whole trick: the ghost sets off late and lands late,
  // so it trails Pac-Man without needing a position offset of its own.
  Behavior on ghostPos {
    enabled: root.hasSnapped
    SequentialAnimation {
      PauseAnimation { duration: 140 }
      NumberAnimation { id: ghostAnim; duration: 200; easing.type: Easing.InOutQuad }
    }
  }

  function travelTo(index) {
    if (index < 0) return

    if (!root.hasSnapped) {
      root.tripStart = index
      root.pacPos = index
      root.ghostPos = index
      root.hasSnapped = true
      return
    }

    var distance = Math.abs(index - root.pacPos)
    if (distance < 0.001) return

    // Duration is read when the Behavior fires, so set it before assigning.
    travelAnim.duration = Math.max(130, Math.round(distance * 190 / root.speed))
    ghostAnim.duration = travelAnim.duration
    root.tripDir = index > root.pacPos ? 1 : -1
    root.facing = root.tripDir
    root.tripStart = root.pacPos
    root.pacPos = index
    root.ghostPos = index

    respawnTimer.interval = travelAnim.duration + 380
    respawnTimer.restart()

    // The ghost is only worth showing while there is a chase to see: parked
    // next to Pac-Man on a five-slot track he just sits on top of a pellet.
    root.ghostShown = true
    ghostHideTimer.interval = travelAnim.duration + 300
    ghostHideTimer.restart()
  }

  // Collapsing the trip to a point is what makes the eaten pellets come back:
  // a pellet counts as eaten only while it lies between tripStart and pacPos.
  Timer {
    id: respawnTimer
    interval: 600
    onTriggered: {
      root.tripStart = root.pacPos
      root.facing = 1
    }
  }

  Timer {
    id: ghostHideTimer
    interval: 600
    onTriggered: root.ghostShown = false
  }

  onFocusedIndexChanged: root.travelTo(root.focusedIndex)
  Component.onCompleted: root.travelTo(root.focusedIndex)

  readonly property bool chomping: root.chomp === "always"
    || (root.chomp === "travel" && travelAnim.running)
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

  // -------------------------------------------------------------------- slots
  Repeater {
    model: root.ids

    WidgetButton {
      id: slot

      required property int index
      required property int modelData

      readonly property var workspace: root.workspaceById(modelData)
      readonly property bool occupied: workspace !== null && workspace.toplevels.values.length > 0
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
      readonly property bool urgent: root.urgentMode !== "none"
        && workspace !== null && workspace.urgent && occupied && !focused
      property bool blinkOn: true
      // Under Pac-Man right now.
      readonly property bool covered: root.style === "pacman"
        && root.focusedIndex >= 0
        && Math.abs(root.pacPos - index) < 0.42
      // Passed on this trip, and not yet respawned.
      readonly property bool eaten: root.style === "pacman" && root.eat
        && (index - root.tripStart) * root.tripDir > 0.001
        && (root.pacPos - index) * root.tripDir > -0.2

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
      fontSize: root.markerFontSize
      foreground: focused && root.style !== "pacman" ? root.activeColor : root.baseColor
      // WidgetButton paints `activeColor`, the bar's own urgent colour, while
      // this is true, and cross-fades back when it goes false.
      active: urgent && (root.urgentMode === "color" || blinkOn)
      opacity: covered || eaten ? 0 : (occupied || focused || urgent ? 1 : root.dim)
      horizontalMargin: 0
      verticalPadding: 6
      // Numbers say which workspace they are; pellets do not.
      tooltipText: root.style === "numbers" ? "" : "Workspace " + modelData
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
  // A sliding mark on the focused slot. Pac-Man already says where you are,
  // so `auto` only draws this for the other styles, but it is available for
  // all of them: the marker glyphs alone do not survive a theme whose accent
  // matches its foreground.
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
  // Declared after the Repeater so they stack above the pellets.
  Ghost {
    id: ghost
    visible: root.style === "pacman" && root.ghostEnabled && root.focusedIndex >= 0
    width: root.pacSize * 0.92
    height: root.pacSize * 0.92
    color: root.baseColor
    opacity: root.ghostShown ? 0.6 : 0
    look: root.vertical ? 0 : root.facing

    Behavior on opacity { NumberAnimation { duration: 220 } }
    x: root.vertical ? (root.barSize - width) / 2 : root.slotCenter(root.ghostPos) - width / 2
    y: root.vertical ? root.slotCenter(root.ghostPos) - height / 2 : (root.barSize - height) / 2
  }

  Pacman {
    id: pacman
    visible: root.style === "pacman" && root.focusedIndex >= 0
    width: root.pacSize
    height: root.pacSize
    color: root.activeColor
    rotation: root.vertical ? (root.facing >= 0 ? 90 : 270) : (root.facing >= 0 ? 0 : 180)
    x: root.vertical ? (root.barSize - width) / 2 : root.slotCenter(root.pacPos) - width / 2
    y: root.vertical ? root.slotCenter(root.pacPos) - height / 2 : (root.barSize - height) / 2

    Behavior on rotation { NumberAnimation { duration: 110 } }
  }
}
