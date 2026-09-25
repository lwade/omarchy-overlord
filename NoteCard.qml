import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: card

  property string noteId: ""
  property string label: ""
  property bool dragging: false
  property bool fading: false
  property bool showDelete: false
  property bool showTick: false
  property string tickTip: ""
  property color foreground: Color.foreground
  property color dim: Qt.darker(foreground, 1.55)
  property color urgent: Color.urgent
  property string fontFamily: Style.font.family

  signal activated()
  signal deleteRequested()
  signal tickRequested()
  signal dragMoved(real x, real y)
  signal dragFinished(real x, real y)

  height: Math.max(Style.space(28), Style.font.body + Style.space(10))
  radius: Style.cornerRadius
  color: mouse.containsMouse && !dragging
    ? Style.selectedFillFor(foreground, Color.accent)
    : "transparent"
  border.width: 0

  Text {
    anchors.fill: parent
    anchors.leftMargin: showTick ? Style.space(22) : Style.space(4)
    anchors.rightMargin: showDelete ? Style.space(26) : Style.space(4)
    text: card.label
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
    color: fading ? card.dim : card.foreground
    font.family: card.fontFamily
    font.weight: fading ? Font.Light : Font.Normal
    font.italic: fading
    font.pixelSize: Style.font.body
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    preventStealing: true
    property real startX: 0
    property real startY: 0
    property bool held: false
    property bool moved: false
    hoverEnabled: true

    onPressed: function(m) {
      held = true
      startX = m.x
      startY = m.y
      moved = false
    }

    onPositionChanged: function(m) {
      if (!held) return
      if (!moved && (Math.abs(m.x - startX) > 4 || Math.abs(m.y - startY) > 4))
        moved = true
      if (moved) card.dragMoved(m.x, m.y)
    }

    onReleased: function(m) {
      if (!held) return
      held = false
      if (moved) card.dragFinished(m.x, m.y)
      else card.activated()
      moved = false
    }

    onCanceled: function() {
      if (held && moved) card.dragFinished(startX, startY)
      held = false
      moved = false
    }
  }

  Rectangle {
    id: tick
    visible: card.showTick
    z: 2
    anchors.left: parent.left
    anchors.leftMargin: Style.space(4)
    anchors.verticalCenter: parent.verticalCenter
    width: Style.space(12)
    height: width
    radius: Math.min(2, Style.cornerRadius)
    color: "transparent"
    border.width: 1
    border.color: tickMouse.containsMouse ? Color.accent : card.dim

    Text {
      anchors.centerIn: parent
      visible: tickMouse.containsMouse
      text: "✓"
      color: Color.accent
      font.family: card.fontFamily
      font.pixelSize: Math.max(8, Style.font.caption - 1)
    }

    MouseArea {
      id: tickMouse
      anchors.fill: parent
      anchors.margins: -Style.space(4)
      hoverEnabled: true
      preventStealing: true
      cursorShape: Qt.PointingHandCursor
      onClicked: card.tickRequested()
    }

    PanelToolTip {
      visible: card.tickTip !== "" && tickMouse.containsMouse
      text: card.tickTip
      fontFamily: card.fontFamily
    }
  }

  PanelActionButton {
    anchors.right: parent.right
    anchors.verticalCenter: parent.verticalCenter
    visible: card.showDelete
    z: 2
    iconText: "×"
    tooltipText: "Delete"
    foreground: fading ? card.dim : card.foreground
    hoverColor: card.urgent
    fontFamily: card.fontFamily
    fontSize: Style.font.body
    onClicked: card.deleteRequested()
  }
}
