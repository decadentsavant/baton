// Pure helpers for the Baton widget. No Qt types in here on purpose: every
// function is a plain data transform so the protocol can be exercised with
// `node dev/model-test.js` without standing up a shell.

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
function parseFrame(line) {
  var text = String(line || "").replace(/^\s+|\s+$/g, "")
  if (text === "") return null
  try {
    var frame = JSON.parse(text)
    if (!frame || typeof frame !== "object") return null
    if (typeof frame.type !== "string") return null
    return frame
  } catch (e) {
    return null
  }
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

  if (!s.connected) lines.push("Baton — offline")
  else if (s.pending) lines.push("Sending a wave…")
  else if (s.cooldownRemaining > 0) lines.push("Next wave in " + cooldownLabel(s.cooldownRemaining))
  else if (s.baton) lines.push("Click to pass the baton on")
  else lines.push("Click to wave at an Omarchy user")

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

// Reconnect backoff, capped. The relay holds an idle connection open for
// minutes at a time, so a tight retry loop after a network blip would hammer
// it for no benefit.
function backoffMs(attempt, random) {
  var n = Math.max(0, Math.floor(Number(attempt) || 0))
  var cap = Math.min(60000, 1000 * Math.pow(2, Math.min(n, 6)))
  return typeof random === "number" ? Math.floor(cap * (0.5 + Math.max(0, Math.min(1, random)) * 0.5)) : cap
}

function cooldownDeadline(seconds, nowMs) {
  var value = Number(seconds)
  return nowMs + (isFinite(value) ? Math.max(0, value) : 0) * 1000
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
