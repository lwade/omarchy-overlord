import QtQuick
import Quickshell.Io

FocusScope {
  id: field

  property alias text: editor.text
  property alias font: editor.font
  property color color: "white"
  property color selectionColor: "#888888"
  property string placeholderText: ""
  property color placeholderColor: "#808080"
  property bool wrap: false
  property int maximumLength: 8192
  property int pasteGeneration: 0
  signal escapePressed()
  signal returnPressed()
  signal textEdited()

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
    Keys.onEscapePressed: function(event) {
      field.escapePressed()
      event.accepted = true
    }
    Keys.onReturnPressed: function(event) {
      if (field.wrap) return
      field.returnPressed()
      event.accepted = true
    }
    Keys.onPressed: function(event) {
      if (event.matches(StandardKey.Paste)) {
        field.requestPaste(false)
        event.accepted = true
      }
    }
    onTextChanged: field.textEdited()
  }

  Text {
    anchors.fill: editor
    visible: editor.length === 0 && editor.preeditText.length === 0
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
