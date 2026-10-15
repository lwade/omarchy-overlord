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
  property bool admitAgain: false
  property string writePath: ""
  property int writeGeneration: 0
  property string writeMode: ""
  property string pendingBody: ""
  property bool writeAgain: false
  property bool protectThenReload: false
  readonly property url ioUrl: Qt.resolvedUrl("board-io")

  readonly property bool simple: board.simple === true
  readonly property bool confirmDelete: board.confirmDelete !== false
  readonly property string defaultDir: {
    var base = Quickshell.env("XDG_DATA_HOME")
    if (!base) base = Quickshell.env("HOME") + "/.local/share"
    return base + "/omarchy-overlord"
  }
  readonly property string dataDir: notesDir !== "" ? notesDir : defaultDir
  readonly property string boardPath: dataDir + "/overlord.json"
  readonly property bool defaultStore: dataDir === defaultDir

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
    root.startMkdir()
  }

  function helper() {
    return root.ioUrl.toString()
  }

  function startMkdir() {
    ensureProc.command = [
      root.helper(),
      root.defaultStore ? "ensure-private" : "ensure",
      root.dataDir
    ]
    if (ensureProc.running) mkdirAgain = true
    else ensureProc.running = true
  }

  function protectDefaultStore(thenReload) {
    protectThenReload = thenReload
    if (!root.defaultStore) {
      if (thenReload && root.boardPath === root.expectedPath) root.admit()
      return
    }
    if (protectStore.running) return
    protectStore.command = [
      "bash", "-c",
      "chmod 0700 \"$1\" || exit 1; for f in \"$1/overlord.json\" \"$1/board.json\"; do if [ -e \"$f\" ] && [ ! -L \"$f\" ]; then chmod 0600 \"$f\" || exit 1; fi; done",
      "overlord-protect",
      root.defaultDir
    ]
    protectStore.running = true
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

  function admit() {
    if (root.boardPath !== root.expectedPath) return
    if (admitProc.running) {
      admitAgain = true
      return
    }
    admitProc.command = [root.helper(), "admit", root.boardPath]
    admitProc.running = true
  }

  function onAdmitted(exitCode) {
    var path = boardPath
    var gen = loadGeneration
    if (admitAgain) {
      admitAgain = false
      root.admit()
      return
    }
    if (!root.sameLoad(path, gen)) return
    if (exitCode === 0) {
      root.applyRaw(admitOut.text)
      return
    }
    if (exitCode === 3) {
      root.requestWrite(path, gen, "create")
      return
    }
    if (exitCode === 2 || exitCode === 4 || exitCode === 5) {
      console.warn("overlord: notes file refused (" + exitCode + ")")
      return
    }
    root.retryLoad()
  }

  function requestWrite(path, gen, mode) {
    if (!root.sameLoad(path, gen)) return
    if (mode === "save" && !loaded) return
    writePath = path
    writeGeneration = gen
    writeMode = mode
    if (writer.running) {
      writeAgain = true
      return
    }
    pendingBody = mode === "create"
      ? Model.serialize(Model.emptyBoard())
      : Model.serialize(board)
    var ioMode = mode === "create" && root.defaultStore ? "create-private" : mode
    writer.stdinEnabled = true
    writer.command = [root.helper(), ioMode, path]
    writer.running = true
  }

  function onWriterStarted() {
    writer.write(root.pendingBody)
    writer.stdinEnabled = false
  }

  function onWriter(exitCode) {
    var path = writePath
    var gen = writeGeneration
    var mode = writeMode
    var body = pendingBody
    if (writeAgain) {
      writeAgain = false
      root.requestWrite(boardPath, loadGeneration, loaded ? "save" : "create")
      return
    }
    if (!root.sameLoad(path, gen)) return
    if (mode === "create") {
      if (exitCode === 0) root.applyRaw(body)
      else if (exitCode === 17) root.admit()
      return
    }
    if (exitCode === 0 && root.defaultStore) root.protectDefaultStore(false)
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
    onTriggered: root.admit()
  }

  Process {
    id: ensureProc
    onExited: function(exitCode) {
      if (root.mkdirAgain) {
        root.mkdirAgain = false
        root.startMkdir()
        return
      }
      if (exitCode !== 0 || root.boardPath !== root.expectedPath) {
        if (exitCode !== 0) console.warn("overlord: notes path refused")
        return
      }
      root.protectDefaultStore(true)
    }
  }

  Process {
    id: protectStore
    onExited: {
      if (!root.protectThenReload) return
      root.protectThenReload = false
      if (root.boardPath !== root.expectedPath) return
      root.admit()
    }
  }

  Process {
    id: admitProc
    stdout: StdioCollector { id: admitOut }
    onExited: function(exitCode) { root.onAdmitted(exitCode) }
  }

  Process {
    id: writer
    stdinEnabled: true
    onStarted: root.onWriterStarted()
    onExited: function(exitCode) { root.onWriter(exitCode) }
  }

  Component.onCompleted: {
    ready = true
    root.ensureDir()
  }
}
