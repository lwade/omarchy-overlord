import QtQuick
import QtTest

Item {
  id: root
  width: 64
  height: 64

  Rectangle {
    anchors.fill: parent
    color: "#101315"
  }

  Loader {
    id: icon
    source: "../Star.qml"
  }

  TestCase {
    name: "StarRender"
    when: windowShown && icon.status === Loader.Ready

    function isInk(img, x, y) {
      return img.red(x, y) > 180 && img.green(x, y) > 180 && img.blue(x, y) > 180
    }

    function isBg(img, x, y) {
      return img.red(x, y) < 40 && img.green(x, y) < 40 && img.blue(x, y) < 40
    }

    function assertStar(size) {
      icon.item.iconSize = size
      icon.item.color = "#e8e6e3"
      tryCompare(icon.item, "width", size)
      tryVerify(function() {
        var shot = grabImage(icon.item)
        if (shot.width < size || shot.width !== shot.height) return false
        var edge = shot.width - 1
        return isBg(shot, 0, 0) && isBg(shot, edge, 0) && isBg(shot, 0, edge) && isBg(shot, edge, edge)
      }, 1000)
      var img = grabImage(icon.item)
      compare(img.height, img.width)
      verify(img.width >= size)
      var n = img.width

      verify(isBg(img, 0, 0), "corner filled")
      verify(isBg(img, n - 1, 0), "corner filled")
      verify(isBg(img, 0, n - 1), "corner filled")
      verify(isBg(img, n - 1, n - 1), "corner filled")

      var cx = Math.round((n - 1) / 2)
      var cy = cx
      verify(isInk(img, cx, cy), "star center empty")
      verify(Math.abs(img.red(cx, cy) - 232) < 20, "center tint")
      verify(Math.abs(img.green(cx, cy) - 230) < 20, "center tint")

      verify(isInk(img, cx, 0) || isInk(img, cx, 1), "circle missing at top")
      verify(isInk(img, 0, cy) || isInk(img, 1, cy), "circle missing at left")
      var sawStroke = false
      var sawGap = false
      for (var y = 0; y < cy; y++) {
        if (isInk(img, cx, y)) sawStroke = true
        else if (sawStroke) sawGap = true
      }
      verify(sawGap, "circle and star are one blob")

      var ink = 0
      var bg = 0
      var mismatches = 0
      var mass = 0
      for (var y = 0; y < n; y++) {
        for (var x = 0; x < n; x++) {
          var on = isInk(img, x, y)
          if (on) {
            ink++
            mass += x
          } else if (isBg(img, x, y)) {
            bg++
          }
          if (on !== isInk(img, n - 1 - x, y)) mismatches++
        }
      }
      verify(ink > n, "icon has no body")
      verify(ink < n * n * 0.5, "icon filled its square")
      verify(bg > n, "no hole inside the circle")
      verify(mismatches < n * n * 0.08, "asymmetric star, mismatches " + mismatches)
      verify(Math.abs(mass / ink - (n - 1) / 2) < Math.max(1.5, n * 0.04), "star is off center")

    }

    function test_barIcon() { assertStar(16) }
    function test_heroIcon() { assertStar(24) }
    function test_largeIcon() { assertStar(64) }
  }
}
