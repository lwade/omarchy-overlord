import QtQuick
import Quickshell.Io

FocusScope {
  id: field
  clip: true

  property alias text: editor.text
  property alias font: editor.font
  property color color: "white"
  property color selectionColor: "#888888"
  property string placeholderText: ""
  property color placeholderColor: "#808080"
  property bool wrap: false
  property int maximumLength: 8192
  property int pasteGeneration: 0
  property Item keyHandler: null
  readonly property real contentHeight: editor.contentHeight
  signal escapePressed()
  signal returnPressed()
  signal textEdited()

  function matchesPaste(event) {
    return event && event.matches(StandardKey.Paste)
  }

  // Parked: TextEdit does not deliver Ctrl+Return to these handlers, and a
  // window shortcut would not stay inside this panel. Do not bind it globally.
  function finishChord(event) {
    if (!wrap || !event) return false
    var key = event.key === Qt.Key_Return || event.key === Qt.Key_Enter
    return key && (event.modifiers & Qt.ControlModifier)
  }

  function takeFinish(event) {
    if (!finishChord(event)) return
    returnPressed()
    event.accepted = true
  }

  function requestPaste(primary) {
    if (pasteProc.running) pasteProc.signal(15)
    pasteGeneration++
    var gen = pasteGeneration
    pasteTimer.gen = gen
    pasteProc.command = [
      "bash", "-c",
      primary
        ? "wl-paste -n -p -t text/plain | head -c 8193"
        : "wl-paste -n -t text/plain | head -c 8193"
    ]
    pasteProc.gen = gen
    pasteProc.running = true
    pasteTimer.restart()
  }

  function insertPaste(value, gen) {
    if (gen !== pasteGeneration || !activeFocus) return
    if (!value || value.length > maximumLength) return
    if (editor.text.length - editor.selectedText.length + value.length > maximumLength) return
    editor.cursorSelection.text = value
  }

  Rectangle {
    anchors.fill: parent
    color: "transparent"
    border.width: 1
    border.color: Qt.rgba(field.color.r, field.color.g, field.color.b, 0.35)
    radius: 4
  }

  TextEdit {
    id: editor
    anchors.fill: parent
    anchors.margins: 6
    focus: true
    textFormat: TextEdit.PlainText
    wrapMode: field.wrap ? TextEdit.Wrap : TextEdit.NoWrap
    selectByMouse: true
    color: field.color
    selectionColor: field.selectionColor
    font: field.font
    clip: true
    Keys.priority: Keys.BeforeItem
    Keys.forwardTo: field.keyHandler ? [field.keyHandler] : []
    Keys.onEscapePressed: function(event) {
      field.escapePressed()
      event.accepted = true
    }
    Keys.onReturnPressed: function(event) { field.takeFinish(event) }
    Keys.onEnterPressed: function(event) { field.takeFinish(event) }
    Keys.onShortcutOverride: function(event) {
      if (field.finishChord(event)) event.accepted = true
    }
    Keys.onPressed: function(event) {
      if (field.matchesPaste(event)) {
        field.requestPaste(false)
        event.accepted = true
        return
      }
      field.takeFinish(event)
    }
    onTextChanged: field.textEdited()
  }

  Text {
    x: editor.x + (field.wrap ? editor.cursorRectangle.x : 0)
    y: editor.y + (field.wrap ? editor.cursorRectangle.y : 0)
    width: Math.max(0, editor.width - (x - editor.x))
    height: field.wrap ? Math.max(implicitHeight, editor.cursorRectangle.height) : editor.height
    visible: editor.length === 0 && editor.preeditText.length === 0 && field.placeholderText !== ""
    text: field.placeholderText
    textFormat: Text.PlainText
    color: field.placeholderColor
    font: editor.font
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
  }

  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.MiddleButton
    onClicked: function(mouse) {
      field.forceActiveFocus()
      var point = editor.mapFromItem(field, mouse.x, mouse.y)
      editor.cursorPosition = editor.positionAt(point.x, point.y)
      field.requestPaste(true)
    }
  }

  Process {
    id: pasteProc
    property int gen: 0
    stdout: StdioCollector { id: pasteOut; waitForEnd: true }
    onExited: function(exitCode) {
      pasteTimer.stop()
      if (exitCode !== 0 || gen !== field.pasteGeneration) return
      var value = pasteOut.text || ""
      if (value.length > field.maximumLength) return
      field.insertPaste(value, gen)
    }
  }

  Timer {
    id: pasteTimer
    property int gen: 0
    interval: 1000
    onTriggered: {
      field.pasteGeneration++
      if (pasteProc.running) pasteProc.signal(15)
    }
  }
}
