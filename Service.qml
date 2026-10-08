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
  property int loadAttempts: 0

  readonly property bool simple: board.simple === true
  readonly property bool confirmDelete: board.confirmDelete !== false
  readonly property string defaultDir: {
    var base = Quickshell.env("XDG_DATA_HOME")
    if (!base) base = Quickshell.env("HOME") + "/.local/share"
    return base + "/omarchy-overlord"
  }
  readonly property string dataDir: notesDir !== "" ? notesDir : defaultDir
  readonly property string boardPath: dataDir + "/overlord.json"

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

  function boardTextOk(raw) {
    var text = String(raw || "")
    if (!text.trim()) return true
    try {
      var data = JSON.parse(text)
      return !!(data && data.version === 1 && Array.isArray(data.cards))
    } catch (e) {
      return false
    }
  }

  function retryLoad() {
    if (loadAttempts >= 3) return
    loadAttempts++
    retryTimer.restart()
  }

  function onBoardLoadFailed(error) {
    if (error !== FileViewError.FileNotFound) {
      root.retryLoad()
      return
    }
    if (!missingCheck.running) missingCheck.running = true
  }

  function createBoard() {
    root.applyRaw("")
    if (root.loaded) boardFile.setText(Model.serialize(root.board))
  }

  function applyRaw(raw) {
    if (!root.boardTextOk(raw)) {
      root.retryLoad()
      return
    }
    var parsed = Model.parse(raw)
    var flushed = Model.flush(parsed, Date.now())
    board = flushed
    loaded = true
    loadAttempts = 0
    if (flushed !== parsed) boardFile.setText(Model.serialize(flushed))
  }

  Timer {
    interval: 60000
    repeat: true
    running: root.loaded
    onTriggered: root.flushNow()
  }

  Timer {
    id: retryTimer
    interval: 1000
    onTriggered: boardFile.reload()
  }

  Process {
    id: missingCheck
    command: ["test", "!", "-e", root.boardPath]
    onExited: function(exitCode) {
      if (exitCode === 0) root.createBoard()
      else root.retryLoad()
    }
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
    onLoadFailed: function(error) { root.onBoardLoadFailed(error) }
  }

  Component.onCompleted: {
    ready = true
    root.ensureDir()
  }
}
