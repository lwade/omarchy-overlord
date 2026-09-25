import QtQuick
import QtQuick.Window
import QtQuick.Shapes

Item {
  id: root

  property real iconSize: 16
  property color color: "transparent"
  readonly property real dpr: Screen.devicePixelRatio > 1 ? Screen.devicePixelRatio : 1
  readonly property real stroke: Math.max(1.25, iconSize * 0.075)
  readonly property string circlePath: {
    var cx = width / 2
    var cy = height / 2
    var r = Math.max(1, (Math.min(width, height) - stroke) / 2)
    var x = cx.toFixed(4)
    var top = (cy - r).toFixed(4)
    var bottom = (cy + r).toFixed(4)
    var rr = r.toFixed(4)
    return "M" + x + "," + top
      + "A" + rr + "," + rr + " 0 1 1 " + x + "," + bottom
      + "A" + rr + "," + rr + " 0 1 1 " + x + "," + top
      + "Z"
  }
  readonly property string starPath: {
    var cx = width / 2
    var cy = height / 2
    var outer = Math.min(width, height) * 0.31
    var inner = outer * 0.42
    var d = ""
    for (var i = 0; i < 10; i++) {
      var angle = (-90 + i * 36) * Math.PI / 180
      var radius = i % 2 === 0 ? outer : inner
      d += (i === 0 ? "M" : "L") + (cx + radius * Math.cos(angle)).toFixed(4)
        + "," + (cy + radius * Math.sin(angle)).toFixed(4)
    }
    return d + "Z"
  }

  width: iconSize
  height: iconSize
  implicitWidth: iconSize
  implicitHeight: iconSize

  Shape {
    anchors.fill: parent
    antialiasing: true
    preferredRendererType: Shape.CurveRenderer
    layer.enabled: true
    layer.smooth: true
    layer.samples: 8
    layer.textureSize: Qt.size(Math.ceil(root.width * root.dpr * 2), Math.ceil(root.height * root.dpr * 2))

    ShapePath {
      strokeColor: root.color
      strokeWidth: root.stroke
      fillColor: "transparent"
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.circlePath }
    }

    ShapePath {
      fillColor: root.color
      strokeColor: root.color
      strokeWidth: Math.max(0.6, root.iconSize * 0.02)
      capStyle: ShapePath.RoundCap
      joinStyle: ShapePath.RoundJoin
      PathSvg { path: root.starPath }
    }
  }
}
