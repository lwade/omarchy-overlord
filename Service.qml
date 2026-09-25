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

  property string notesDir: ""
  property bool mkdirAgain: false
  property bool ready: false

  readonly property bool simple: board.simple === true
  readonly property bool confirmDelete: board.confirmDelete !== false
  readonly property string defaultDir: {
    var base = Quickshell.env("XDG_DATA_HOME")
    if (!base) base = Quickshell.env("HOME") + "/.local/share"
    return base + "/omarchy-overlord"
  }
  readonly property string dataDir: notesDir !== "" ? notesDir : defaultDir
  readonly property string boardPath: dataDir + "/overlord.json"
  readonly property string legacyPath: dataDir + "/board.json"

  function setNotesDir(dir) {
    var next = Model.notesDir(dir)
    if (next === notesDir) return
    loaded = false
    notesDir = next
  }

  onBoardPathChanged: if (ready) root.ensureDir()

  function ensureDir() {
    loaded = false
    if (mkdir.running) mkdirAgain = true
    else mkdir.running = true
  }

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

  function importLegacy(raw) {
    if (!raw || !String(raw).trim()) {
      applyRaw("")
      return
    }
    applyRaw(raw)
    if (loaded) boardFile.setText(Model.serialize(board))
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
    onExited: {
      if (root.mkdirAgain) {
        root.mkdirAgain = false
        running = true
        return
      }
      boardFile.reload()
    }
  }

  FileView {
    id: boardFile
    path: root.boardPath
    watchChanges: false
    atomicWrites: true
    printErrors: false
    onLoaded: root.applyRaw(text())
    onLoadFailed: legacyFile.reload()
  }

  FileView {
    id: legacyFile
    path: root.legacyPath
    watchChanges: false
    atomicWrites: false
    printErrors: false
    onLoaded: root.importLegacy(text())
    onLoadFailed: root.applyRaw("")
  }

  Component.onCompleted: {
    ready = true
    root.ensureDir()
  }
}
