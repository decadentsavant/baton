// Pure helpers for the Baton widget. No Qt types in here on purpose: every
// function is a plain data transform so the protocol can be exercised with
// `node dev/model-test.js` without standing up a shell.

// Must match "version" in manifest.json; dev/model-test.js checks that. The
// widget cannot read its own manifest cheaply, and the relay needs a number to
// compare against, so the number lives here too.
var VERSION = "1.0.3"
var PLUGIN_ID = "io.github.decadentsavant.baton"
var UPDATE_COMMAND = "omarchy plugin update " + PLUGIN_ID
var RESTART_COMMAND = "omarchy-restart-shell"

// One relay frame. The wire format is newline-delimited JSON rather than SSE
// framing, because SplitParser already gives us line splitting for free and a
// bare object is far easier to eyeball with curl.
//
//   {"type":"wave","origin":"PL"}
//   {"type":"stats","total":120491,"online":3847}
//   {"type":"ping"}
//
// Anything unparseable is dropped rather than thrown: the stream is long-lived
// and a single truncated line must not take the widget down.
//
// The relay is public and pluggable, so its output is untrusted. A frame
// longer than MAX_FRAME_CHARS is dropped before JSON.parse runs (the shell
// side enforces the same ceiling in bytes before the line is buffered at
// all), and what survives is copied field by field onto a fresh object:
// only the fields the widget uses, strings clipped, numbers finite, and the
// baton reduced to its four known facts. Nothing else from the wire is kept.
var MAX_FRAME_CHARS = 4096
var MAX_TEXT_CHARS = 64

function parseFrame(line) {
  var text = String(line || "").replace(/^\s+|\s+$/g, "")
  if (text === "") return null
  if (text.length > MAX_FRAME_CHARS) return null
  try {
    var raw = JSON.parse(text)
    if (!raw || typeof raw !== "object") return null
    if (typeof raw.type !== "string") return null
    return sanitizeFrame(raw)
  } catch (e) {
    return null
  }
}

function clipText(value, max) {
  return typeof value === "string" ? value.slice(0, max) : undefined
}

function finiteNumber(value) {
  return typeof value === "number" && isFinite(value) ? value : undefined
}

function sanitizeBaton(raw) {
  if (!raw || typeof raw !== "object") return undefined
  var baton = {}
  var id = clipText(raw.id, 128)
  var born = clipText(raw.born, MAX_TEXT_CHARS)
  var hops = finiteNumber(raw.hops)
  var countries = finiteNumber(raw.countries)
  if (id !== undefined) baton.id = id
  if (born !== undefined) baton.born = born
  if (hops !== undefined) baton.hops = hops
  if (countries !== undefined) baton.countries = countries
  return baton
}

function sanitizeFrame(raw) {
  var frame = { type: clipText(raw.type, MAX_TEXT_CHARS) }
  var origin = clipText(raw.origin, 8)
  var minClient = clipText(raw.minClient, MAX_TEXT_CHARS)
  var remaining = finiteNumber(raw.remaining)
  var total = finiteNumber(raw.total)
  var online = finiteNumber(raw.online)
  var baton = sanitizeBaton(raw.baton)
  if (origin !== undefined) frame.origin = origin
  if (minClient !== undefined) frame.minClient = minClient
  if (remaining !== undefined) frame.remaining = remaining
  if (total !== undefined) frame.total = total
  if (online !== undefined) frame.online = online
  if (typeof raw.delivered === "boolean") frame.delivered = raw.delivered
  if (baton !== undefined) frame.baton = baton
  return frame
}

// Settings arrive as whatever shell.json holds. The settings panel writes real
// booleans; `omarchy bar set key true` writes the string "true" unless the
// caller adds --json. Accept both so the documented command does what it says.
function asBool(value, fallback) {
  if (value === true || value === false) return value
  if (typeof value === "string") {
    var text = value.trim().toLowerCase()
    if (text === "true" || text === "1" || text === "yes" || text === "on") return true
    if (text === "false" || text === "0" || text === "no" || text === "off") return false
  }
  if (typeof value === "number") return value !== 0
  return fallback === true
}

// ISO 3166-1 alpha-2 -> flag emoji. Regional indicators sit at U+1F1E6 for
// "A", so each letter maps by offset. Anything that isn't two ASCII letters
// (including the deliberate "??" the relay sends for opted-out senders) gets
// no flag at all.
function flagFor(code) {
  var cc = String(code || "").toUpperCase()
  if (!/^[A-Z]{2}$/.test(cc)) return ""
  var first = 0x1F1E6 + (cc.charCodeAt(0) - 65)
  var second = 0x1F1E6 + (cc.charCodeAt(1) - 65)
  return String.fromCodePoint(first, second)
}

// The reveal. This single string is the entire emotional payload of the
// product, so it stays deliberately plain: a place, never a person.
function originLabel(code, countryNames) {
  var cc = String(code || "").toUpperCase()
  if (!/^[A-Z]{2}$/.test(cc)) return "somewhere"
  var names = countryNames || {}
  return names[cc] || cc
}

function waveHeadline(code, countryNames) {
  var flag = flagFor(code)
  var where = originLabel(code, countryNames)
  // A sender who opted out of sharing their country still deserves a line that
  // reads like a sentence. "Someone in somewhere" is not one.
  if (where === "somewhere") return "Someone, somewhere"
  return (flag === "" ? "" : flag + "  ") + "Someone in " + where
}

// Human-readable cooldown. Scarcity is the feature — a wave you can send every
// second is worth nothing — so the widget has to state the wait plainly rather
// than just going dead.
function cooldownLabel(seconds) {
  var s = Math.max(0, Math.floor(Number(seconds) || 0))
  if (s === 0) return ""
  if (s < 60) return s + "s"
  var m = Math.floor(s / 60)
  if (m < 60) return m + "m"
  var h = Math.floor(m / 60)
  return h + "h" + (m % 60 === 0 ? "" : " " + (m % 60) + "m")
}

function formatCount(n) {
  var v = Math.max(0, Math.floor(Number(n) || 0))
  return String(v).replace(/\B(?=(\d{3})+(?!\d))/g, ",")
}

// Tooltip text, assembled from whatever the widget currently knows. Every
// field is optional because the stream may not have delivered stats yet.
function tooltipText(state) {
  var s = state || {}
  var lines = []

  if (!s.connected) {
    lines.push("Baton — offline")
    if (s.stale) lines.push("Update installed \u2014 finish it with " + RESTART_COMMAND)
    else if (s.identityError) lines.push("Could not create an identity \u2014 check ~/.local/state/baton")
    else if (s.unreachable) lines.push("Can't reach the relay \u2014 still retrying")
  }
  else if (s.pending) lines.push("Sending a wave…")
  else if (s.cooldownRemaining > 0) lines.push("Next wave in " + cooldownLabel(s.cooldownRemaining))
  else if (s.baton) lines.push("Click to pass the baton on")
  else lines.push("Click to wave at an Omarch")

  if (s.outdated) lines.push("Update available \u2014 " + UPDATE_COMMAND)
  else if (s.stale && s.connected) lines.push("Update installed \u2014 finish it with " + RESTART_COMMAND)
  if (s.baton) lines.push("Holding a baton \u2014 " + batonLabel(s.baton, s.nowMs))
  if (s.nobodyAround) lines.push("Your last wave found nobody online")
  if (s.lastOrigin) lines.push("Last wave from " + originLabel(s.lastOrigin, s.countryNames))
  if (s.showCounter && s.globalTotal > 0) lines.push(formatCount(s.globalTotal) + " waves sent")
  if (s.showCounter && s.online > 0) lines.push(formatCount(s.online) + " online now")

  return lines.join("\n")
}

// "alive since" in words. Deliberately coarse: a baton that has been going for
// three weeks is interesting, and the fact that it is three weeks and two days
// is not. Coarseness is also the safer choice, since a precise age plus a hop
// count narrows down when a specific person was online.
function ageLabel(bornIso, nowMs) {
  var born = Date.parse(String(bornIso || ""))
  if (isNaN(born)) return ""
  var now = typeof nowMs === "number" ? nowMs : Date.now()
  var mins = Math.floor((now - born) / 60000)
  if (mins < 1) return "just now"
  if (mins < 60) return mins + (mins === 1 ? " minute" : " minutes")
  var hours = Math.floor(mins / 60)
  if (hours < 24) return hours + (hours === 1 ? " hour" : " hours")
  var days = Math.floor(hours / 24)
  if (days < 14) return days + (days === 1 ? " day" : " days")
  var weeks = Math.floor(days / 7)
  if (weeks < 9) return weeks + " weeks"
  var months = Math.floor(days / 30)
  return months + (months === 1 ? " month" : " months")
}

// The three facts a baton knows about itself, as one line.
function batonLabel(baton, nowMs) {
  if (!baton) return ""
  var hops = Math.max(0, Math.floor(Number(baton.hops) || 0))
  var countries = Math.max(0, Math.floor(Number(baton.countries) || 0))
  var parts = [formatCount(hops) + (hops === 1 ? " hop" : " hops")]

  var age = ageLabel(baton.born, nowMs)
  if (age === "just now") parts.push("born just now")
  else if (age !== "") parts.push("alive " + age)

  if (countries > 0) parts.push(countries + (countries === 1 ? " country" : " countries"))
  return parts.join(" \u00b7 ")
}

// A plugin is a git clone that only moves when its owner runs the update
// command, so the relay tells each client the oldest version it still fully
// supports and the widget compares. Dotted integers, compared numerically per
// segment with missing segments as zero. An empty or malformed floor never
// counts as "behind": the worst outcome of a bad frame must be silence, not a
// nag.
function versionBefore(current, minimum) {
  var parse = function(v) {
    var text = String(v || "").trim()
    if (!/^\d+(\.\d+)*$/.test(text)) return null
    return text.split(".").map(function(part) { return parseInt(part, 10) })
  }
  var a = parse(current), b = parse(minimum)
  if (!a || !b) return false
  for (var i = 0; i < Math.max(a.length, b.length); i++) {
    var x = a[i] || 0, y = b[i] || 0
    if (x !== y) return x < y
  }
  return false
}

// Reconnect backoff, capped. The relay holds an idle connection open for
// minutes at a time, so a tight retry loop after a network blip would hammer
// it for no benefit. Once the relay has been out of reach for a while (a
// laptop off the network, a relay that has gone away) the retry slows to
// SLOW_RETRY_MS so a dead relay costs one curl every few minutes, not every
// minute, for the rest of the session.
var SLOW_RETRY_AFTER = 10
var SLOW_RETRY_MS = 300000

function backoffMs(attempt, random) {
  var n = Math.max(0, Math.floor(Number(attempt) || 0))
  var cap = n >= SLOW_RETRY_AFTER ? SLOW_RETRY_MS : Math.min(60000, 1000 * Math.pow(2, Math.min(n, 6)))
  return typeof random === "number" ? Math.floor(cap * (0.5 + Math.max(0, Math.min(1, random)) * 0.5)) : cap
}

// The relay decides the cooldown, but a relay is untrusted input like any
// other, so one absurd number must not park the button for the rest of the
// session. The real cooldown is measured in minutes; a day is the ceiling.
var MAX_COOLDOWN_SECONDS = 86400

function cooldownDeadline(seconds, nowMs) {
  var value = Number(seconds)
  return nowMs + (isFinite(value) ? Math.min(MAX_COOLDOWN_SECONDS, Math.max(0, value)) : 0) * 1000
}

function remainingSeconds(deadline, nowMs) {
  return Math.max(0, Math.ceil((deadline - nowMs) / 1000))
}

// How long the clock can sleep before the cooldown label would change. Under a
// minute the label counts seconds; above it, only the minute matters, so the
// next tick lands on the next minute boundary. With no cooldown, a slow tick
// keeps a held baton's age fresh.
function tickMs(remaining) {
  var s = Math.max(0, Math.floor(Number(remaining) || 0))
  if (s === 0) return 60000
  if (s <= 60) return 1000
  return ((s % 60) || 60) * 1000
}

function batonUrl(relayUrl, baton) {
  var base = String(relayUrl).replace(/\/+$/, "")
  return baton && baton.id ? base + "/b/" + encodeURIComponent(baton.id) : base + "/"
}

function inviteText(relayUrl, baton, nowMs) {
  var story = baton ? "This baton has travelled " + batonLabel(baton, nowMs) + "." : "Wave at a random Omarchy user, somewhere in the world."
  return story + " Put a wave in your Omarchy bar. " + batonUrl(relayUrl, baton)
}
