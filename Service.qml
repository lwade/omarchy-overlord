import QtQuick
import Quickshell
import Quickshell.Io
import "Model.js" as Model

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var board: Model.emptyBoard()
  property bool loaded: false

  readonly property bool simple: board.simple === true
  readonly property bool confirmDelete: board.confirmDelete !== false
  readonly property string dataDir: {
    var base = Quickshell.env("XDG_DATA_HOME")
    if (!base) base = Quickshell.env("HOME") + "/.local/share"
    return base + "/omarchy-overlord"
  }
  readonly property string boardPath: dataDir + "/board.json"

  function commit(next) {
    if (!next || next === board) return
    board = next
    if (loaded) boardFile.setText(Model.serialize(board))
  }

  function add(text, quadrant) {
    if (!String(text || "").trim()) return
    commit(Model.added(board, text, Date.now(), quadrant || "do"))
  }

  function updateText(id, text) {
    commit(Model.withText(board, id, text, Date.now()))
  }

  function place(id, name) {
    commit(Model.moved(board, id, name, Date.now()))
  }

  function remove(id) {
    commit(Model.without(board, id))
  }

  function tick(id) {
    commit(Model.ticked(board, id))
  }

  function setSimple(value) {
    commit(Model.withSimple(board, value))
  }

  function setConfirmDelete(value) {
    commit(Model.withConfirmDelete(board, value))
  }

  function flushNow() {
    commit(Model.flush(board, Date.now()))
  }

  function applyRaw(raw) {
    var parsed = Model.parse(raw)
    var flushed = Model.flush(parsed, Date.now())
    board = flushed
    loaded = true
    if (flushed !== parsed) boardFile.setText(Model.serialize(flushed))
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.loaded
    onTriggered: root.flushNow()
  }

  Process {
    id: mkdir
    command: ["mkdir", "-p", root.dataDir]
    onExited: boardFile.reload()
  }

  FileView {
    id: boardFile
    path: root.boardPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyRaw(text())
    onLoadFailed: root.applyRaw("")
  }

  Component.onCompleted: mkdir.running = true
}
