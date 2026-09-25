import QtQuick
import QtTest
import "../Model.js" as Model

TestCase {
  name: "Model"

  function card(id, text, urgent, important, extra) {
    var next = {
      id: id,
      text: text,
      urgent: urgent,
      important: important,
      createdAt: 1,
      updatedAt: 1
    }
    if (extra) {
      for (var key in extra) next[key] = extra[key]
    }
    return next
  }

  function load(cards, extra) {
    var raw = {
      version: 1,
      simple: !!(extra && extra.simple),
      confirmDelete: !(extra && extra.confirmDelete === false),
      stats: extra && extra.stats ? extra.stats : {},
      cards: cards || []
    }
    return Model.parse(JSON.stringify(raw))
  }

  function test_notesDir() {
    compare(Model.notesDir(""), "")
    compare(Model.notesDir("relative/path"), "")
    compare(Model.notesDir("/cloud/notes/"), "/cloud/notes")
    compare(Model.notesDir("/cloud/../notes"), "")
    compare(Model.notesDir("  /home/lzw/Nextcloud/overlord  "), "/home/lzw/Nextcloud/overlord")
  }

  function test_emptyBoardDefaults() {
    var board = Model.emptyBoard()
    compare(board.version, 1)
    compare(board.simple, false)
    compare(board.confirmDelete, true)
    compare(board.cards.length, 0)
    compare(board.stats.do, 0)
    compare(board.stats.schedule, 0)
    compare(board.stats.delegate, 0)
    compare(board.stats.eliminate, 0)
  }

  function test_parseRejectsGarbage() {
    var empty = Model.emptyBoard()
    function sameShape(board) {
      compare(board.version, empty.version)
      compare(board.simple, false)
      compare(board.confirmDelete, true)
      compare(board.cards.length, 0)
      compare(board.stats.do, 0)
    }
    sameShape(Model.parse(""))
    sameShape(Model.parse("   "))
    sameShape(Model.parse("not json"))
    sameShape(Model.parse("null"))
    sameShape(Model.parse('{"version":2,"cards":[{"id":"a","text":"kept"}]}'))
    sameShape(Model.parse('{"version":1}'))
    sameShape(Model.parse('{"cards":[{"id":"a","text":"kept"}]}'))
  }

  function test_parseDropsInvalidCardsAndIgnoresStoredQuadrant() {
    var board = Model.parse(JSON.stringify({
      version: 1,
      cards: [
        null,
        { text: "no id" },
        { id: "blank", text: "   " },
        { id: "ok", text: "  kept  ", quadrant: "drop", urgent: false, important: true }
      ]
    }))
    compare(board.cards.length, 1)
    compare(board.cards[0].id, "ok")
    compare(board.cards[0].text, "  kept  ")
    compare(Model.quadrant(board.cards[0]), "schedule")
    var saved = JSON.parse(Model.serialize(board))
    verify(!saved.cards[0].hasOwnProperty("quadrant"))
  }

  function test_missingFlagsLandInDo() {
    var board = Model.parse('{"version":1,"cards":[{"id":"a","text":"x"}]}')
    compare(board.cards[0].urgent, true)
    compare(board.cards[0].important, true)
    compare(board.cards[0].delegatedAt, null)
    compare(Model.quadrant(board.cards[0]), "do")
  }

  function test_quadrantsAreDerived() {
    compare(Model.quadrant({ urgent: true, important: true }), "do")
    compare(Model.quadrant({ urgent: false, important: true }), "schedule")
    compare(Model.quadrant({ urgent: true, important: false }), "delegate")
    compare(Model.quadrant({ urgent: false, important: false }), "drop")
    compare(Model.statKey("do"), "do")
    compare(Model.statKey("schedule"), "schedule")
    compare(Model.statKey("delegate"), "delegate")
    compare(Model.statKey("drop"), "eliminate")
    compare(Model.statKey("eliminate"), "eliminate")
    compare(Model.statKey(""), "do")
  }

  function test_statsLoadMissingAsZeroAndKeepLegacyKeys() {
    var missing = Model.parse('{"version":1,"cards":[]}')
    compare(missing.stats.do, 0)
    compare(missing.stats.schedule, 0)
    compare(missing.stats.delegate, 0)
    compare(missing.stats.eliminate, 0)

    var legacy = Model.parse('{"version":1,"cards":[],"stats":{"created":4,"eliminated":1,"flushed":2}}')
    compare(legacy.stats.do, 4)
    compare(legacy.stats.eliminate, 3)

    var modern = Model.parse('{"version":1,"cards":[],"stats":{"do":1,"created":9,"eliminate":0,"flushed":9,"schedule":1.9,"delegate":"4"}}')
    compare(modern.stats.do, 1)
    compare(modern.stats.eliminate, 0)
    compare(modern.stats.schedule, 1)
    compare(modern.stats.delegate, 4)

    var junk = Model.parse('{"version":1,"cards":[],"stats":{"do":-2,"schedule":null,"delegate":"nope","eliminate":Infinity}}')
    compare(junk.stats.do, 0)
    compare(junk.stats.schedule, 0)
    compare(junk.stats.delegate, 0)
    compare(junk.stats.eliminate, 0)
  }

  function test_flagsRoundTrip() {
    var board = Model.parse('{"version":1,"cards":[],"simple":true,"confirmDelete":false}')
    compare(board.simple, true)
    compare(board.confirmDelete, false)
    var saved = JSON.parse(Model.serialize(board))
    compare(saved.version, 1)
    compare(saved.simple, true)
    compare(saved.confirmDelete, false)
    compare(saved.stats.do, 0)
    verify(Model.serialize(board).endsWith("\n"))

    var defaults = Model.parse('{"version":1,"cards":[]}')
    compare(defaults.simple, false)
    compare(defaults.confirmDelete, true)
  }

  function test_togglesAreNoOpsWhenUnchanged() {
    var board = Model.emptyBoard()
    verify(Model.withSimple(board, false) === board)
    verify(Model.withConfirmDelete(board, true) === board)
    var simple = Model.withSimple(board, true)
    compare(simple.simple, true)
    compare(simple.cards, board.cards)
    verify(Model.withSimple(simple, true) === simple)
    var asking = Model.withConfirmDelete(board, false)
    compare(asking.confirmDelete, false)
    verify(Model.withConfirmDelete(asking, false) === asking)
  }

  function test_addPlacesNewestFirstAndCountsTheFiling() {
    var board = Model.added(Model.emptyBoard(), "one", 10, "do")
    board = Model.added(board, "two", 11, "schedule")
    board = Model.added(board, "three", 12, "delegate")
    board = Model.added(board, "four", 13, "drop")
    compare(board.cards.length, 4)
    compare(board.cards[0].text, "four")
    compare(board.cards[3].text, "one")
    compare(Model.quadrant(Model.find(board, board.cards[3].id)), "do")
    compare(Model.quadrant(Model.find(board, board.cards[2].id)), "schedule")
    compare(Model.quadrant(Model.find(board, board.cards[1].id)), "delegate")
    compare(Model.quadrant(Model.find(board, board.cards[0].id)), "drop")
    compare(board.cards[1].delegatedAt, 12)
    compare(board.cards[0].delegatedAt, null)
    compare(board.stats.do, 0)
    compare(board.stats.schedule, 0)
    compare(board.stats.delegate, 1)
    compare(board.stats.eliminate, 1)
    verify(board.cards[0].id !== board.cards[1].id)
  }

  function test_moveUpdatesFlagsWithoutMutatingTheOriginal() {
    var board = Model.added(Model.emptyBoard(), "note", 10, "do")
    var id = board.cards[0].id
    var original = board.cards[0]
    var scheduled = Model.moved(board, id, "schedule", 20)
    compare(original.urgent, true)
    compare(original.important, true)
    compare(scheduled.cards[0].urgent, false)
    compare(scheduled.cards[0].important, true)
    compare(scheduled.cards[0].delegatedAt, null)
    compare(scheduled.cards[0].updatedAt, 20)
    compare(scheduled.stats.do, 0)
    compare(scheduled.stats.schedule, 0)
    verify(Model.moved(scheduled, id, "schedule", 30) === scheduled)

    var delegated = Model.moved(scheduled, id, "delegate", 40)
    compare(delegated.cards[0].urgent, true)
    compare(delegated.cards[0].important, false)
    compare(delegated.cards[0].delegatedAt, 40)
    compare(delegated.stats.delegate, 1)

    var back = Model.moved(delegated, id, "do", 50)
    compare(back.cards[0].delegatedAt, null)
    compare(Model.quadrant(back.cards[0]), "do")
    compare(back.stats.do, 0)
    compare(back.stats.schedule, 0)
    compare(back.stats.delegate, 1)
  }

  function test_dropMoveDeletesAndDropAddKeeps() {
    var board = Model.added(Model.emptyBoard(), "note", 10, "do")
    var id = board.cards[0].id
    var dropped = Model.moved(board, id, "drop", 20)
    compare(dropped.cards.length, 0)
    compare(dropped.stats.do, 0)
    compare(dropped.stats.eliminate, 1)
    compare(Model.find(dropped, id), null)

    var filed = Model.added(Model.emptyBoard(), "bin", 10, "drop")
    compare(filed.cards.length, 1)
    compare(Model.quadrant(filed.cards[0]), "drop")
    compare(filed.stats.eliminate, 1)
  }

  function test_deleteAndBlankTextCountAsEliminate() {
    var board = Model.added(Model.emptyBoard(), "note", 10, "schedule")
    var id = board.cards[0].id
    verify(Model.without(board, "missing") === board)
    var removed = Model.without(board, id)
    compare(removed.cards.length, 0)
    compare(removed.stats.schedule, 0)
    compare(removed.stats.eliminate, 1)

    var edited = Model.withText(board, id, "  renamed  ", 30)
    compare(edited.cards[0].text, "  renamed  ")
    compare(edited.cards[0].updatedAt, 30)
    compare(edited.stats.eliminate, 0)
    verify(Model.withText(board, "missing", "nope", 30) === board)

    var cleared = Model.withText(board, id, " \n ", 40)
    compare(cleared.cards.length, 0)
    compare(cleared.stats.eliminate, 1)
  }

  function test_tickCountsTheOutcomeOnce() {
    var board = Model.added(Model.emptyBoard(), "ship", 10, "do")
    board = Model.added(board, "plan", 11, "schedule")
    board = Model.added(board, "ask", 12, "delegate")
    var doId = board.cards[2].id
    var scheduleId = board.cards[1].id
    var delegateId = board.cards[0].id
    compare(board.stats.do, 0)
    compare(board.stats.schedule, 0)

    var done = Model.ticked(board, doId)
    compare(done.cards.length, 2)
    compare(Model.find(done, doId), null)
    compare(done.stats.do, 1)
    compare(done.stats.schedule, 0)
    compare(done.stats.eliminate, 0)
    verify(Model.ticked(done, doId) === done)

    var scheduled = Model.ticked(done, scheduleId)
    compare(Model.find(scheduled, scheduleId), null)
    compare(scheduled.stats.schedule, 1)
    compare(scheduled.stats.do, 1)
    verify(Model.ticked(scheduled, delegateId) === scheduled)
    compare(scheduled.stats.delegate, 1)
    compare(scheduled.stats.eliminate, 0)
  }

  function test_searchAndSummary() {
    var board = load([
      card("a", "Alpha\nbody", true, true),
      card("b", "  \nbeta line", false, true),
      card("c", "gamma", true, false)
    ])
    compare(Model.summary(board.cards[0].text), "Alpha")
    compare(Model.summary(board.cards[1].text), "beta line")
    compare(Model.summary(""), "")
    compare(Model.inQuadrant(board, "do", "").length, 1)
    compare(Model.inQuadrant(board, "do", "   ").length, 1)
    compare(Model.inQuadrant(board, "schedule", "BETA").length, 1)
    compare(Model.inQuadrant(board, "do", "beta").length, 0)
    compare(Model.inQuadrant(board, "delegate", "gamma")[0].id, "c")
    compare(Model.find(board, "missing"), null)
  }

  function test_flushRemovesOnlyStaleDelegatesAndCountsThem() {
    var now = 1700000000000
    var due = now - Model.DAY_MS
    var fresh = due + 1
    var board = load([
      card("stale", "stale handoff", true, false, { delegatedAt: due }),
      card("also", "also stale", true, false, { delegatedAt: due - 5 }),
      card("fresh", "Ask Sam", true, false, { delegatedAt: fresh }),
      card("undated", "no stamp", true, false),
      card("drop", "bin me", false, false, { delegatedAt: due - 5 }),
      card("do", "Ship the note", true, true)
    ], { stats: { do: 1, schedule: 0, delegate: 3, eliminate: 1 }, simple: true })

    var edge = load([
      card("edge", "edge", true, false, { delegatedAt: 1000 })
    ])
    verify(Model.flush(edge, 1000 + Model.DAY_MS - 1) === edge)
    var edged = Model.flush(edge, 1000 + Model.DAY_MS)
    compare(edged.cards.length, 0)
    compare(edged.stats.eliminate, 1)

    var next = Model.flush(board, now)
    compare(next.cards.length, 4)
    compare(Model.find(next, "stale"), null)
    compare(Model.find(next, "also"), null)
    verify(Model.find(next, "fresh") !== null)
    verify(Model.find(next, "undated") !== null)
    verify(Model.find(next, "drop") !== null)
    compare(next.stats.eliminate, 3)
    compare(next.stats.delegate, 3)
    compare(next.stats.do, 1)
    compare(next.simple, true)
    compare(next.confirmDelete, true)
    verify(Model.flush(next, now) === next)
  }
}
