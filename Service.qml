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
  property int loadGeneration: 0
  property string expectedPath: ""
  property string checkedPath: ""
  property int checkedGeneration: 0
  property bool checkAgain: false
  property string writePath: ""
  property int writeGeneration: 0
  property string writeMode: ""
  property bool writeAgain: false

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
    notesDir = next
  }

  onBoardPathChanged: if (ready) root.ensureDir()

  function beginLoad() {
    loadGeneration++
    loadAttempts = 0
    retryTimer.stop()
    loaded = false
    expectedPath = boardPath
  }

  function ensureDir() {
    root.beginLoad()
    if (mkdir.running) mkdirAgain = true
    else mkdir.running = true
  }

  function commit(next) {
    if (!loaded || !next || next === board) return
    board = next
    root.requestWrite(boardPath, loadGeneration, "save")
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

  function sameLoad(path, gen) {
    return gen === loadGeneration && path === boardPath && path === expectedPath
  }

  function retryLoad() {
    if (loadAttempts >= 3) return
    loadAttempts++
    retryTimer.restart()
  }

  function onBoardLoadFailed(error) {
    if (boardPath !== expectedPath) return
    loaded = false
    if (error !== FileViewError.FileNotFound) {
      root.retryLoad()
      return
    }
    root.confirmMissing(boardPath, loadGeneration)
  }

  function confirmMissing(path, gen) {
    if (!root.sameLoad(path, gen)) return
    checkedPath = path
    checkedGeneration = gen
    if (missingCheck.running) {
      checkAgain = true
      return
    }
    missingCheck.command = ["test", "!", "-e", path]
    missingCheck.running = true
  }

  function onMissingChecked(exitCode) {
    var path = checkedPath
    var gen = checkedGeneration
    if (checkAgain) {
      checkAgain = false
      root.confirmMissing(boardPath, loadGeneration)
      return
    }
    if (!root.sameLoad(path, gen)) return
    if (exitCode !== 0) {
      root.retryLoad()
      return
    }
    root.requestWrite(path, gen, "create")
  }

  function requestWrite(path, gen, mode) {
    if (!root.sameLoad(path, gen)) return
    if (mode === "save" && !loaded) return
    writePath = path
    writeGeneration = gen
    writeMode = mode
    if (writeGuard.running) {
      writeAgain = true
      return
    }
    writeGuard.command = mode === "create"
      ? ["test", "!", "-e", path, "-a", "!", "-L", path]
      : ["test", "!", "-L", path]
    writeGuard.running = true
  }

  function onWriteGuard(exitCode) {
    var path = writePath
    var gen = writeGeneration
    var mode = writeMode
    if (writeAgain) {
      writeAgain = false
      root.requestWrite(boardPath, loadGeneration, loaded ? "save" : "create")
      return
    }
    if (exitCode !== 0 || !root.sameLoad(path, gen)) return
    if (mode === "create") {
      root.applyRaw("")
      if (root.loaded && root.sameLoad(path, gen))
        boardFile.setText(Model.serialize(board))
      return
    }
    if (!loaded) return
    boardFile.setText(Model.serialize(board))
  }

  function applyRaw(raw) {
    if (boardPath !== expectedPath) return
    if (!root.boardTextOk(raw)) {
      loaded = false
      root.retryLoad()
      return
    }
    retryTimer.stop()
    var parsed = Model.parse(raw)
    var flushed = Model.flush(parsed, Date.now())
    board = flushed
    loaded = true
    loadAttempts = 0
    if (flushed !== parsed) root.requestWrite(boardPath, loadGeneration, "save")
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
    onExited: function(exitCode) { root.onMissingChecked(exitCode) }
  }

  Process {
    id: writeGuard
    onExited: function(exitCode) { root.onWriteGuard(exitCode) }
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
      if (root.boardPath !== root.expectedPath) return
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
