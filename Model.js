.pragma library

var DAY_MS = 24 * 60 * 60 * 1000

function emptyStats() {
  return { do: 0, schedule: 0, delegate: 0, eliminate: 0 }
}

function countOf(n) {
  var v = Number(n)
  return isFinite(v) && v > 0 ? Math.floor(v) : 0
}

function statKey(quadrant) {
  if (quadrant === "schedule" || quadrant === "delegate") return quadrant
  if (quadrant === "drop" || quadrant === "eliminate") return "eliminate"
  return "do"
}

function statsOf(board) {
  var raw = board && board.stats ? board.stats : {}
  var eliminate = raw.eliminate !== undefined
    ? countOf(raw.eliminate)
    : countOf(raw.eliminated) + countOf(raw.flushed)
  return {
    do: raw.do !== undefined ? countOf(raw.do) : countOf(raw.created),
    schedule: countOf(raw.schedule),
    delegate: countOf(raw.delegate),
    eliminate: eliminate
  }
}

function bumpStats(board, key, by) {
  var stats = statsOf(board)
  stats[key] = stats[key] + (by || 1)
  return stats
}

function emptyBoard() {
  return { version: 1, simple: false, confirmDelete: true, stats: emptyStats(), cards: [] }
}

function flag(value, fallback) {
  return typeof value === "boolean" ? value : fallback
}

function copy(card) {
  return {
    id: card.id,
    text: card.text,
    urgent: card.urgent === true,
    important: card.important === true,
    delegatedAt: typeof card.delegatedAt === "number" ? card.delegatedAt : null,
    createdAt: card.createdAt,
    updatedAt: card.updatedAt
  }
}

function normalize(card) {
  if (!card || !card.id) return null
  var text = typeof card.text === "string" ? card.text : ""
  if (!text.trim()) return null
  return {
    id: String(card.id),
    text: text,
    urgent: flag(card.urgent, true),
    important: flag(card.important, true),
    delegatedAt: typeof card.delegatedAt === "number" ? card.delegatedAt : null,
    createdAt: typeof card.createdAt === "number" ? card.createdAt : Date.now(),
    updatedAt: typeof card.updatedAt === "number" ? card.updatedAt : Date.now()
  }
}

function boardOf(board, cards, overrides) {
  var extra = overrides || {}
  var simple = extra.simple !== undefined ? extra.simple === true : !!(board && board.simple)
  var confirmDelete = extra.confirmDelete !== undefined
    ? extra.confirmDelete !== false
    : !(board && board.confirmDelete === false)
  var stats = extra.stats ? statsOf({ stats: extra.stats }) : statsOf(board)
  return { version: 1, simple: simple, confirmDelete: confirmDelete, stats: stats, cards: cards || [] }
}

function parse(raw) {
  if (!raw || !String(raw).trim()) return emptyBoard()
  try {
    var data = JSON.parse(raw)
    if (!data || data.version !== 1 || !Array.isArray(data.cards)) return emptyBoard()
    var cards = []
    for (var i = 0; i < data.cards.length; i++) {
      var card = normalize(data.cards[i])
      if (card) cards.push(card)
    }
    return boardOf(data, cards)
  } catch (e) {
    return emptyBoard()
  }
}

function serialize(board) {
  var next = board && Array.isArray(board.cards) ? board : emptyBoard()
  return JSON.stringify({
    version: 1,
    simple: next.simple === true,
    confirmDelete: next.confirmDelete !== false,
    stats: statsOf(next),
    cards: next.cards
  }, null, 2) + "\n"
}

function quadrant(card) {
  var urgent = !!(card && card.urgent)
  var important = !!(card && card.important)
  if (urgent && important) return "do"
  if (important) return "schedule"
  if (urgent) return "delegate"
  return "drop"
}

function summary(text) {
  var lines = String(text || "").split("\n")
  for (var i = 0; i < lines.length; i++) {
    var line = lines[i].trim()
    if (line) return line
  }
  return ""
}

function find(board, id) {
  var cards = board && board.cards ? board.cards : []
  for (var i = 0; i < cards.length; i++) {
    if (cards[i].id === id) return cards[i]
  }
  return null
}

function inQuadrant(board, name, query) {
  var q = String(query || "").trim().toLowerCase()
  var cards = board && board.cards ? board.cards : []
  var out = []
  for (var i = 0; i < cards.length; i++) {
    if (quadrant(cards[i]) !== name) continue
    if (q && String(cards[i].text).toLowerCase().indexOf(q) === -1) continue
    out.push(cards[i])
  }
  return out
}

function create(text, now) {
  return {
    id: now.toString(36) + Math.random().toString(36).slice(2, 8),
    text: String(text),
    urgent: true,
    important: true,
    delegatedAt: null,
    createdAt: now,
    updatedAt: now
  }
}

function placeCard(card, name, now) {
  if (quadrant(card) === name) return card
  var next = copy(card)
  next.updatedAt = now
  if (name === "do") {
    next.urgent = true
    next.important = true
    next.delegatedAt = null
  } else if (name === "schedule") {
    next.urgent = false
    next.important = true
    next.delegatedAt = null
  } else if (name === "delegate") {
    next.urgent = true
    next.important = false
    next.delegatedAt = now
  } else if (name === "drop") {
    next.urgent = false
    next.important = false
    next.delegatedAt = null
  }
  return next
}

function withText(board, id, text, now) {
  var cards = []
  var found = false
  var removed = false
  var list = board.cards || []
  for (var i = 0; i < list.length; i++) {
    var card = list[i]
    if (card.id !== id) {
      cards.push(card)
      continue
    }
    found = true
    if (!String(text || "").trim()) {
      removed = true
      continue
    }
    var next = copy(card)
    next.text = String(text)
    next.updatedAt = now
    cards.push(next)
  }
  if (!found) return board
  if (removed) return boardOf(board, cards, { stats: bumpStats(board, "eliminate", 1) })
  return boardOf(board, cards)
}

function without(board, id) {
  var cards = []
  var found = false
  var list = board.cards || []
  for (var i = 0; i < list.length; i++) {
    if (list[i].id === id) {
      found = true
      continue
    }
    cards.push(list[i])
  }
  if (!found) return board
  return boardOf(board, cards, { stats: bumpStats(board, "eliminate", 1) })
}

function countsOnFile(name) {
  var key = statKey(name)
  return key === "delegate" || key === "eliminate"
}

function added(board, text, now, quadrant) {
  var card = create(text, now)
  if (quadrant && quadrant !== "do") card = placeCard(card, quadrant, now)
  var cards = (board.cards || []).slice()
  cards.unshift(card)
  if (!countsOnFile(quadrant)) return boardOf(board, cards)
  return boardOf(board, cards, { stats: bumpStats(board, statKey(quadrant), 1) })
}

function moved(board, id, name, now) {
  if (name === "drop") return without(board, id)
  var cards = []
  var changed = false
  var list = board.cards || []
  for (var i = 0; i < list.length; i++) {
    var card = list[i]
    if (card.id !== id) {
      cards.push(card)
      continue
    }
    var next = placeCard(card, name, now)
    if (next !== card) changed = true
    cards.push(next)
  }
  if (!changed) return board
  if (!countsOnFile(name)) return boardOf(board, cards)
  return boardOf(board, cards, { stats: bumpStats(board, statKey(name), 1) })
}

function ticked(board, id) {
  var card = find(board, id)
  if (!card) return board
  var name = quadrant(card)
  if (name !== "do" && name !== "schedule") return board
  var cards = []
  var list = board.cards || []
  for (var i = 0; i < list.length; i++) {
    if (list[i].id !== id) cards.push(list[i])
  }
  return boardOf(board, cards, { stats: bumpStats(board, name, 1) })
}

function withSimple(board, simple) {
  if ((board.simple === true) === (simple === true)) return board
  return boardOf(board, board.cards, { simple: simple === true })
}

function withConfirmDelete(board, value) {
  var next = value !== false
  if ((board.confirmDelete !== false) === next) return board
  return boardOf(board, board.cards, { confirmDelete: next })
}

function flush(board, now) {
  var cards = []
  var removed = 0
  var list = board && board.cards ? board.cards : []
  for (var i = 0; i < list.length; i++) {
    var card = list[i]
    if (quadrant(card) === "delegate" && typeof card.delegatedAt === "number" && now - card.delegatedAt >= DAY_MS) {
      removed++
      continue
    }
    cards.push(card)
  }
  if (!removed) return board
  return boardOf(board, cards, { stats: bumpStats(board, "eliminate", removed) })
}
