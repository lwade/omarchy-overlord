import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "io.github.lwade.overlord"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root

  property int serviceLookup: 0
  readonly property var service: {
    serviceLookup
    return bar && bar.shell ? bar.shell.serviceFor(moduleName) : null
  }

  property string query: ""
  property bool composerOpen: false
  property string editingId: ""
  property string newQuadrant: "do"
  property string dragId: ""
  property string dragLabel: ""
  property real dragX: 0
  property real dragY: 0
  property string hoverKey: ""
  property string pendingDeleteId: ""
  property bool confirmOpen: false

  readonly property var board: service && service.board ? service.board : Model.emptyBoard()
  readonly property bool simple: service ? service.simple === true : false
  readonly property bool confirmDelete: service ? service.confirmDelete !== false : true
  readonly property int doCount: {
    board
    return countIn("do")
  }
  readonly property int scheduleCount: {
    board
    return countIn("schedule")
  }
  readonly property int delegateCount: {
    board
    return countIn("delegate")
  }
  readonly property string handledLine: {
    var stats = board && board.stats ? board.stats : {}
    var done = Number(stats.do) || 0
    var scheduled = Number(stats.schedule) || 0
    var delegated = Number(stats.delegate) || 0
    var eliminated = Number(stats.eliminate) || 0
    return done + " Done · " + scheduled + " Scheduled · " + delegated + " Delegated · " + eliminated + " Eliminated"
  }
  readonly property var quadrants: simple
    ? [{ key: "do", label: "Do" }, { key: "schedule", label: "Schedule" }]
    : [
        { key: "do", label: "Do" },
        { key: "schedule", label: "Schedule" },
        { key: "delegate", label: "Delegate" },
        { key: "drop", label: "Eliminate" }
      ]
  readonly property int minRows: 5
  readonly property int maxRows: 10
  readonly property int noteRow: Math.max(Style.space(28), Style.font.body + Style.space(10))
  readonly property int noteGap: Style.space(4)

  function countIn(name) {
    var list = Model.inQuadrant(board, name, "")
    return list ? list.length : 0
  }

  function slotsFor(a, b) {
    var n = Math.max(countIn(a), b ? countIn(b) : 0)
    return Math.max(minRows, Math.min(maxRows, n))
  }

  function heightFor(slots) {
    return slots * noteRow + Math.max(0, slots - 1) * noteGap + Style.space(32)
  }

  readonly property int topSlots: {
    board
    return slotsFor("do", "schedule")
  }
  readonly property int bottomSlots: {
    board
    simple
    return simple ? 0 : slotsFor("delegate", "drop")
  }
  readonly property int topHeight: heightFor(topSlots)
  readonly property int bottomHeight: simple ? 0 : heightFor(bottomSlots)
  readonly property int gridHeight: simple ? topHeight : topHeight + Style.space(8) + bottomHeight
  readonly property color foreground: bar && bar.foreground ? bar.foreground : Color.popups.text
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color urgent: bar && bar.urgent ? bar.urgent : Color.urgent
  readonly property color border: Color.popups.border
  readonly property color background: Color.popups.background
  readonly property int cornerRadius: Style.cornerRadius
  readonly property string fontFamily: bar && bar.fontFamily ? bar.fontFamily : Style.font.family

  Timer {
    interval: 250
    repeat: true
    running: root.bar !== null && root.service === null
    onTriggered: root.serviceLookup++
  }

  function open() {
    composerOpen = false
    editingId = ""
    dragId = ""
    hoverKey = ""
    cancelDelete()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) search.forceActiveFocus()
    })
  }

  function close() {
    if (confirmOpen) return
    if (composerOpen) finishEdit()
    if (confirmOpen) return
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.open()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function clearSearch() {
    query = ""
    search.text = ""
  }

  function handleEscape() {
    if (confirmOpen) cancelDelete()
    else if (composerOpen) finishEdit()
    else if (query) clearSearch()
    else close()
  }

  function askDelete(id) {
    if (!id) return
    pendingDeleteId = id
    confirmOpen = true
  }

  function cancelDelete() {
    pendingDeleteId = ""
    confirmOpen = false
  }

  function commitDelete() {
    var id = pendingDeleteId
    cancelDelete()
    if (service && id) service.remove(id)
  }

  function beginAdd(quadrant) {
    newQuadrant = quadrant || "do"
    editingId = "new"
    composerOpen = true
    Qt.callLater(function() {
      editor.text = ""
      editor.forceActiveFocus()
    })
  }

  function beginEdit(id) {
    var card = Model.find(board, id)
    if (!card) return
    editingId = id
    composerOpen = true
    Qt.callLater(function() {
      editor.text = card.text
      editor.forceActiveFocus()
    })
  }

  function finishEdit() {
    if (!composerOpen) return
    var text = editor.text
    var id = editingId
    composerOpen = false
    editingId = ""
    dragId = ""
    dragLabel = ""
    hoverKey = ""
    var asking = false
    if (service && id === "new") {
      if (String(text || "").trim()) service.add(text, newQuadrant)
    } else if (service && id && !String(text || "").trim()) {
      if (confirmDelete) {
        askDelete(id)
        asking = true
      } else service.remove(id)
    } else if (service && id) {
      service.updateText(id, text)
    }
    if (!asking) Qt.callLater(function() {
      if (root.opened) search.forceActiveFocus()
    })
  }

  function quadrantAt(x, y) {
    var list = [doCell, scheduleCell]
    if (!simple) {
      list.push(delegateCell)
      list.push(dropCell)
    }
    for (var i = 0; i < list.length; i++) {
      var cell = list[i]
      if (!cell || cell.visible === false) continue
      var p = cell.mapFromItem(surface, x, y)
      if (p.x >= 0 && p.y >= 0 && p.x <= cell.width && p.y <= cell.height)
        return cell.key
    }
    return ""
  }

  function trackDrag(item, x, y, id, label) {
    var p = item.mapToItem(surface, x, y)
    dragId = id
    dragLabel = label
    dragX = p.x
    dragY = p.y
    hoverKey = quadrantAt(p.x, p.y)
  }

  function endDrag(item, x, y, id) {
    var p = item.mapToItem(surface, x, y)
    var key = quadrantAt(p.x, p.y)
    dragId = ""
    dragLabel = ""
    hoverKey = ""
    if (!key || !service || !id) return
    if (key === "drop") {
      if (confirmDelete) askDelete(id)
      else service.remove(id)
    } else service.place(id, key)
  }

  component QuadrantBox: Rectangle {
    id: cell
    property string key: ""
    property string label: ""
    property int boxHeight: 0
    readonly property bool hot: root.hoverKey === key

    width: (matrix.width - Style.space(8)) / 2
    height: boxHeight
    visible: boxHeight > 0
    color: "transparent"
    radius: root.cornerRadius
    border.width: 1
    border.color: hot ? (key === "drop" ? root.urgent : Color.accent) : root.border

    PanelActionButton {
      id: addHere
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.rightMargin: Style.space(2)
      anchors.topMargin: Style.space(2)
      iconText: "+"
      tooltipText: "Add here"
      foreground: root.foreground
      hoverColor: Color.accent
      fontFamily: root.fontFamily
      onClicked: root.beginAdd(cell.key)
    }

    Row {
      id: heading
      anchors.left: parent.left
      anchors.right: addHere.left
      anchors.top: parent.top
      anchors.leftMargin: Style.space(8)
      anchors.rightMargin: Style.space(4)
      anchors.topMargin: Style.space(6)
      spacing: Style.space(6)

      PanelSectionHeader {
        id: sectionLabel
        text: cell.label.toUpperCase()
        foreground: cell.key === "drop" ? root.urgent : (cell.hot ? Color.accent : root.foreground)
        fontFamily: root.fontFamily
      }

      Text {
        visible: cell.key === "delegate"
        text: "clears 24h"
        color: root.dim
        font.family: root.fontFamily
        font.pixelSize: Style.font.caption
        anchors.verticalCenter: sectionLabel.verticalCenter
        anchors.verticalCenterOffset: Math.round(sectionLabel.topPadding / 2)
      }
    }

    Flickable {
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.top: heading.bottom
      anchors.margins: Style.space(6)
      anchors.topMargin: Style.space(4)
      contentHeight: notes.implicitHeight
      clip: true
      interactive: contentHeight > height

      Column {
        id: notes
        property string quadrantKey: cell.key
        width: parent.width
        spacing: root.noteGap

        Repeater {
          model: Model.inQuadrant(root.board, cell.key, root.query)

          delegate: NoteCard {
            id: note
            required property var modelData
            width: notes.width
            noteId: modelData.id
            label: Model.summary(modelData.text)
            fading: parent.quadrantKey === "delegate"
            showTick: parent.quadrantKey === "do" || parent.quadrantKey === "schedule"
            tickTip: parent.quadrantKey === "schedule" ? "Scheduled" : "Done"
            showDelete: root.simple
            foreground: root.foreground
            dim: root.dim
            urgent: root.urgent
            fontFamily: root.fontFamily
            dragging: root.dragId === modelData.id
            onActivated: root.beginEdit(note.noteId)
            onDeleteRequested: {
              if (root.confirmDelete) root.askDelete(note.noteId)
              else if (root.service) root.service.remove(note.noteId)
            }
            onTickRequested: if (root.service) root.service.tick(note.noteId)
            onDragMoved: function(x, y) {
              root.trackDrag(note, x, y, note.noteId, note.label)
            }
            onDragFinished: function(x, y) {
              root.endDrag(note, x, y, note.noteId)
            }
          }
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.cappedContentHeight(boardColumn.implicitHeight + panel.verticalContentInset)

    Item {
      id: surface
      anchors.fill: parent

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true
        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (root.confirmOpen && confirmDialog.handleKey(event)) {
            event.accepted = true
            return
          }
        }
        Keys.onEscapePressed: function(event) {
          root.handleEscape()
          event.accepted = true
        }
        Keys.onTabPressed: function(event) {
          root.switchPanel(event.modifiers & Qt.ShiftModifier ? -1 : 1)
          event.accepted = true
        }
        Keys.onBacktabPressed: function(event) {
          root.switchPanel(-1)
          event.accepted = true
        }
      }

      Column {
        id: boardColumn
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(10)

        PanelHero {
          width: parent.width
          title: "Overlord"
          meta: "Action this day"
          foreground: root.foreground
          fontFamily: root.fontFamily
          trailingControl: Component {
            Row {
              spacing: Style.space(6)
              visible: root.doCount + root.scheduleCount + root.delegateCount > 0

              Repeater {
                model: [
                  { n: root.doCount, label: "Do" },
                  { n: root.scheduleCount, label: "Schedule" },
                  { n: root.delegateCount, label: "Delegate" }
                ]

                delegate: BorderSurface {
                  required property var modelData
                  visible: modelData.n > 0
                  implicitWidth: countText.implicitWidth + Style.space(10)
                  implicitHeight: countText.implicitHeight + Style.space(4)
                  color: "transparent"
                  borderSpec: Border.controlSpec("normal", root.foreground, Color.accent)
                  radius: Style.cornerRadius

                  Text {
                    id: countText
                    anchors.centerIn: parent
                    text: modelData.n + " " + modelData.label
                    textFormat: Text.PlainText
                    color: root.dim
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                  }
                }
              }
            }
          }
          iconComponent: Component {
            Star {
              iconSize: Style.font.display
              color: root.foreground
            }
          }
        }

        Text {
          width: parent.width
          text: root.handledLine
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }

        PanelSeparator {
          width: parent.width
          foreground: root.foreground
        }

        Row {
          id: header
          width: parent.width
          spacing: Style.space(8)

          TextField {
            id: search
            width: parent.width - addButton.width - parent.spacing
            height: Style.spacing.controlHeight
            placeholderText: "Search"
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            verticalPadding: Math.max(0, (height - font.pixelSize) / 2 - 1)
            foreground: root.foreground
            onTextChanged: root.query = text
            Keys.onEscapePressed: function(event) {
              root.handleEscape()
              event.accepted = true
            }
          }

          Button {
            id: addButton
            text: "Add"
            bordered: true
            height: search.height
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.body
            onClicked: root.beginAdd()
          }
        }

        PanelSeparator {
          id: sepTools
          width: parent.width
          foreground: root.foreground
        }

        Row {
          id: toggles
          width: parent.width
          spacing: Style.space(16)

          Row {
            spacing: Style.space(6)
            PanelSectionHeader {
              id: simpleLabel
              text: "Simple"
              foreground: root.foreground
              fontFamily: root.fontFamily
              anchors.verticalCenter: parent.verticalCenter
            }
            ToggleSwitch {
              anchors.verticalCenter: simpleLabel.verticalCenter
              anchors.verticalCenterOffset: Math.round(simpleLabel.topPadding / 2)
              checked: root.simple
              trackHeight: Math.round(simpleLabel.font.pixelSize * 1.2)
              cursorPad: Style.space(3)
              foreground: root.foreground
              accent: Color.accent
              onToggled: if (root.service) root.service.setSimple(!checked)
            }
          }

          Row {
            spacing: Style.space(6)
            PanelSectionHeader {
              id: confirmLabel
              text: "Confirm Delete?"
              foreground: root.foreground
              fontFamily: root.fontFamily
              anchors.verticalCenter: parent.verticalCenter
            }
            ToggleSwitch {
              anchors.verticalCenter: confirmLabel.verticalCenter
              anchors.verticalCenterOffset: Math.round(confirmLabel.topPadding / 2)
              checked: root.confirmDelete
              trackHeight: Math.round(confirmLabel.font.pixelSize * 1.2)
              cursorPad: Style.space(3)
              foreground: root.foreground
              accent: Color.accent
              onToggled: if (root.service) root.service.setConfirmDelete(!checked)
            }
          }
        }

        PanelSeparator {
          id: sepBoard
          width: parent.width
          foreground: root.foreground
        }

        Column {
          id: matrix
          width: parent.width
          spacing: Style.space(8)

          Row {
            width: parent.width
            spacing: Style.space(8)

            QuadrantBox {
              id: doCell
              key: "do"
              label: "Do"
              boxHeight: root.topHeight
            }
            QuadrantBox {
              id: scheduleCell
              key: "schedule"
              label: "Schedule"
              boxHeight: root.topHeight
            }
          }

          Row {
            visible: !root.simple
            width: parent.width
            spacing: Style.space(8)

            QuadrantBox {
              id: delegateCell
              key: "delegate"
              label: "Delegate"
              boxHeight: root.bottomHeight
            }
            QuadrantBox {
              id: dropCell
              key: "drop"
              label: "Eliminate"
              boxHeight: root.bottomHeight
            }
          }
        }
      }

      Rectangle {
        visible: root.dragId !== ""
        x: root.dragX - width / 2
        y: root.dragY - height / 2
        z: 5
        width: Style.space(160)
        height: root.noteRow
        radius: Math.min(root.cornerRadius, Style.space(4))
        color: Style.selectedFillFor(root.foreground, Color.accent)
        border.width: 0

        Text {
          anchors.fill: parent
          anchors.leftMargin: Style.space(8)
          anchors.rightMargin: Style.space(8)
          text: root.dragLabel
          elide: Text.ElideRight
          verticalAlignment: Text.AlignVCenter
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }
      }

      ConfirmDialog {
        id: confirmDialog
        anchors.fill: parent
        z: 8
        opened: root.confirmOpen
        message: "Delete this note?"
        confirmText: "Delete"
        background: root.background
        foreground: root.foreground
        fontFamily: root.fontFamily
        onCanceled: root.cancelDelete()
        onConfirmed: root.commitDelete()
      }

      Item {
        anchors.fill: parent
        visible: root.composerOpen
        z: 6

        MouseArea {
          anchors.fill: parent
          onClicked: root.finishEdit()
        }

        Rectangle {
          anchors.fill: parent
          color: root.background

          MouseArea { anchors.fill: parent; onClicked: {} }

          PanelSectionHeader {
            id: noteHeading
            anchors.left: parent.left
            anchors.top: parent.top
            text: "NOTE"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          TextEdit {
            id: editor
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: noteHeading.bottom
            anchors.bottom: done.top
            anchors.topMargin: Style.space(8)
            anchors.bottomMargin: Style.space(8)
            wrapMode: TextEdit.Wrap
            selectByMouse: true
            color: root.foreground
            selectionColor: Style.selectionFillFor(root.foreground, Color.accent)
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            Keys.onEscapePressed: function(event) {
              root.finishEdit()
              event.accepted = true
            }
          }

          Text {
            anchors.left: editor.left
            anchors.top: editor.top
            visible: editor.text.length === 0
            text: "Note"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
          }

          Button {
            id: done
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            text: "Done"
            bordered: true
            foreground: root.foreground
            fontFamily: root.fontFamily
            fontSize: Style.font.caption
            onClicked: root.finishEdit()
          }
        }
      }
    }
  }
}
