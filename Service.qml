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
  property var writingBoard: null
  property var queuedBoard: null
  property string saveError: ""
  property bool protectThenReload: false
  readonly property url ioUrl: Qt.resolvedUrl("board-io")
  readonly property int ioLimitMs: 10000

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
    saveError = ""
    writingBoard = null
    queuedBoard = null
    writeAgain = false
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

  function draft() {
    return queuedBoard || writingBoard || board
  }

  function noteSaveFailed(exitCode) {
    saveError = exitCode === 5
      ? "Not saved. The board is over 1 MiB."
      : "Not saved. The board was left unchanged."
    console.warn("overlord: notes file not saved (" + exitCode + ")")
  }

  function writeConfirmed(exitCode, exitStatus) {
    if (exitCode !== 0) return false
    if (exitStatus === 1 || Number(exitStatus) === 1) return false
    if (String(exitStatus) === "CrashExit") return false
    return true
  }

  function commit(next) {
    if (!loaded || !next || next === draft()) return true
    var raw = Model.serialize(next)
    if (!Model.withinBytes(raw)) {
      saveError = "Not saved. The board is over 1 MiB."
      console.warn("overlord: notes file not saved (5)")
      return false
    }
    saveError = ""
    if (writer.running) {
      queuedBoard = next
      writeAgain = true
      return true
    }
    return root.beginSave(next, raw)
  }

  function beginSave(next, raw) {
    if (!loaded || !root.sameLoad(boardPath, loadGeneration)) return false
    writingBoard = next
    queuedBoard = null
    writeAgain = false
    writePath = boardPath
    writeGeneration = loadGeneration
    writeMode = "save"
    pendingBody = raw
    writer.stdinEnabled = true
    writer.command = [root.helper(), "save", boardPath]
    writer.running = true
    writeWatch.restart()
    return true
  }

  function add(text, quadrant) {
    if (!String(text || "").trim()) return false
    return commit(Model.added(draft(), text, Date.now(), quadrant || "do"))
  }

  function updateText(id, text) {
    return commit(Model.withText(draft(), id, text, Date.now()))
  }

  function place(id, name) {
    return commit(Model.moved(draft(), id, name, Date.now()))
  }

  function remove(id) {
    return commit(Model.without(draft(), id))
  }

  function tick(id) {
    return commit(Model.ticked(draft(), id))
  }

  function setSimple(value) {
    return commit(Model.withSimple(draft(), value))
  }

  function setConfirmDelete(value) {
    return commit(Model.withConfirmDelete(draft(), value))
  }

  function flushNow() {
    return commit(Model.flush(draft(), Date.now()))
  }

  function boardTextOk(raw) {
    var text = String(raw || "")
    if (!text.trim()) return true
    try {
      var data = JSON.parse(text)
      return !!(data && data.version === 1 && Array.isArray(data.cards) && Model.fits(data))
    } catch (e) {
      return false
    }
  }

  function sameLoad(path, gen) {
    return gen === loadGeneration && path === boardPath && path === expectedPath
  }

  function budget() {
    if (loadAttempts >= 3) {
      console.warn("overlord: notes file refused")
      return false
    }
    loadAttempts++
    return true
  }

  function retryLoad() {
    if (!root.budget()) return
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
    admitWatch.restart()
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
      if (!root.budget()) return
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
    writeWatch.restart()
  }

  function onWriterStarted() {
    writer.write(root.pendingBody)
    writer.stdinEnabled = false
  }

  function onWriter(exitCode, exitStatus) {
    var path = writePath
    var gen = writeGeneration
    var mode = writeMode
    var body = pendingBody
    var wrote = writingBoard
    var again = writeAgain
    var queued = queuedBoard
    writeAgain = false
    queuedBoard = null
    writingBoard = null
    if (!root.sameLoad(path, gen)) return
    var confirmed = root.writeConfirmed(exitCode, exitStatus)
    if (again) {
      if (mode === "create" && exitCode === 17) {
        if (root.budget()) root.admit()
        return
      }
      if (mode === "save" && confirmed && wrote) {
        board = wrote
        saveError = ""
        if (!queued && root.defaultStore) root.protectDefaultStore(false)
      } else if (mode === "save" && !confirmed) {
        root.noteSaveFailed(exitCode)
      }
      if (queued && loaded) root.commit(queued)
      else if (!queued && mode === "create" && !confirmed && exitCode !== 17)
        root.requestWrite(boardPath, loadGeneration, "create")
      return
    }
    if (mode === "create") {
      if (confirmed) root.applyRaw(body)
      else if (exitCode === 17) {
        if (!root.budget()) return
        root.admit()
      }
      return
    }
    if (!confirmed) {
      root.noteSaveFailed(exitCode)
      return
    }
    if (wrote) board = wrote
    saveError = ""
    if (root.defaultStore) root.protectDefaultStore(false)
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
    if (!parsed) {
      loaded = false
      console.warn("overlord: notes file refused")
      return
    }
    var flushed = Model.flush(parsed, Date.now())
    board = parsed
    loaded = true
    loadAttempts = 0
    if (flushed !== parsed) root.commit(flushed)
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
    onExited: function(exitCode) {
      admitWatch.stop()
      root.onAdmitted(exitCode)
    }
  }

  Timer {
    id: admitWatch
    interval: root.ioLimitMs
    onTriggered: if (admitProc.running) admitProc.running = false
  }

  Process {
    id: writer
    stdinEnabled: true
    onStarted: root.onWriterStarted()
    onExited: function(exitCode, exitStatus) {
      writeWatch.stop()
      root.onWriter(exitCode, exitStatus)
    }
  }

  Timer {
    id: writeWatch
    interval: root.ioLimitMs
    onTriggered: if (writer.running) writer.running = false
  }

  Component.onCompleted: {
    ready = true
    root.ensureDir()
  }
}
