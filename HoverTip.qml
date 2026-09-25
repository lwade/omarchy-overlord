import QtQuick
import qs.Commons

Rectangle {
  id: root

  property string text: ""
  property bool shown: false
  property real maxTextWidth: Style.space(240)

  readonly property color plate: Qt.rgba(Color.popups.background.r, Color.popups.background.g, Color.popups.background.b, 1)
  readonly property color ink: Qt.rgba(Color.popups.text.r, Color.popups.text.g, Color.popups.text.b, 1)

  visible: shown && text !== ""
  z: 40
  radius: Style.cornerRadius
  color: plate
  border.width: 1
  border.color: Qt.rgba(ink.r, ink.g, ink.b, 0.35)
  width: Math.min(label.implicitWidth, maxTextWidth) + Style.space(16)
  height: label.implicitHeight + Style.space(12)

  Rectangle {
    anchors.fill: parent
    radius: root.radius
    color: root.plate
    z: 0
  }

  Text {
    id: label
    x: Style.space(8)
    y: Style.space(6)
    width: Math.min(implicitWidth, root.maxTextWidth)
    wrapMode: Text.WordWrap
    text: root.text
    textFormat: Text.PlainText
    color: root.ink
    font.family: Style.font.family
    font.pixelSize: Style.font.bodySmall
    z: 1
  }
}
