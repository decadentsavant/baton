// Exercises every pure transform in Model.js without Qt. Run: node dev/model-test.js
const fs = require("fs")
const path = require("path")

const load = (file) => {
  const src = fs.readFileSync(path.join(__dirname, "..", file), "utf8")
  const sandbox = {}
  new Function("exports", src + "\n;Object.assign(exports, typeof NAMES !== 'undefined' ? {NAMES} : {" +
    "cardState, cardAction, parseFrame, flagFor, originLabel, waveHeadline, cooldownLabel, formatCount, countrySet, addCountry, countryCount, backoffMs, ageLabel, batonLabel, cooldownDeadline, remainingSeconds, batonUrl, inviteText, asBool, tickMs, versionBefore, VERSION, PLUGIN_ID, UPDATE_COMMAND, RESTART_COMMAND, MAX_FRAME_CHARS, MAX_TEXT_CHARS, MAX_COOLDOWN_SECONDS, SLOW_RETRY_AFTER, SLOW_RETRY_MS})")(sandbox)
  return sandbox
}

const M = load("Model.js")
const C = load("Countries.js")

let failures = 0
const eq = (label, got, want) => {
  const ok = JSON.stringify(got) === JSON.stringify(want)
  if (!ok) { failures++; console.log(`FAIL ${label}\n  got  ${JSON.stringify(got)}\n  want ${JSON.stringify(want)}`) }
  else console.log(`ok   ${label}`)
}

eq("parseFrame wave", M.parseFrame('{"type":"wave","origin":"PL"}'), { type: "wave", origin: "PL" })
eq("parseFrame truncated line is dropped", M.parseFrame('{"type":"wa'), null)
eq("parseFrame blank", M.parseFrame("   "), null)
eq("parseFrame non-object", M.parseFrame('42'), null)
eq("parseFrame missing type", M.parseFrame('{"origin":"PL"}'), null)

// --- untrusted relay output ---
eq("parseFrame drops a frame over the ceiling", M.parseFrame('{"type":"ping","pad":"' + "x".repeat(M.MAX_FRAME_CHARS) + '"}'), null)
eq("parseFrame keeps a frame at the ceiling", M.parseFrame('{"type":"ping","pad":"' + "x".repeat(M.MAX_FRAME_CHARS - 24) + '"}'), { type: "ping" })
eq("parseFrame drops unknown fields", M.parseFrame('{"type":"wave","origin":"PL","extra":{"deep":[1,2,3]}}'), { type: "wave", origin: "PL" })
eq("parseFrame clips long strings", M.parseFrame('{"type":"wave","origin":"' + "P".repeat(500) + '","minClient":"' + "9".repeat(500) + '"}'),
  { type: "wave", origin: "PPPPPPPP", minClient: "9".repeat(M.MAX_TEXT_CHARS) })
eq("parseFrame drops non-finite and mistyped numbers", M.parseFrame('{"type":"stats","total":1e999,"online":"12","remaining":null}'), { type: "stats" })
eq("parseFrame keeps only the boolean delivered", M.parseFrame('{"type":"cooldown","remaining":60,"delivered":"no"}'), { type: "cooldown", remaining: 60 })
eq("parseFrame keeps a boolean baton pass", M.parseFrame('{"type":"cooldown","remaining":900,"delivered":true,"passed":true}'), { type: "cooldown", remaining: 900, delivered: true, passed: true })
eq("parseFrame drops a mistyped baton pass", M.parseFrame('{"type":"cooldown","remaining":900,"passed":"yes"}'), { type: "cooldown", remaining: 900 })
eq("parseFrame reduces the baton to its known facts",
  M.parseFrame('{"type":"baton","baton":{"id":"abc","born":"2026-09-04T18:00:00Z","hops":3,"countries":2,"owner":"x","hops2":9}}'),
  { type: "baton", baton: { id: "abc", born: "2026-09-04T18:00:00Z", hops: 3, countries: 2 } })
eq("parseFrame drops a baton that is not an object", M.parseFrame('{"type":"state","remaining":0,"baton":"nope"}'), { type: "state", remaining: 0 })
eq("parseFrame drops a null baton", M.parseFrame('{"type":"state","remaining":0,"baton":null}'), { type: "state", remaining: 0 })

eq("flagFor PL", M.flagFor("PL"), "\u{1F1F5}\u{1F1F1}")
eq("flagFor opted-out", M.flagFor("??"), "")
eq("flagFor junk", M.flagFor("A["), "")

eq("originLabel known", M.originLabel("NL", C.NAMES), "the Netherlands")
eq("originLabel unknown code falls back to the code", M.originLabel("ZW", C.NAMES), "ZW")
eq("originLabel opted-out", M.originLabel("??", C.NAMES), "somewhere")

eq("waveHeadline", M.waveHeadline("SE", C.NAMES), "\u{1F1F8}\u{1F1EA}  Someone in Sweden")
eq("waveHeadline opted-out reads as a sentence", M.waveHeadline("??", C.NAMES), "Someone, somewhere")
eq("cooldownLabel seconds", M.cooldownLabel(45), "45s")
eq("cooldownLabel minutes", M.cooldownLabel(600), "10m")
eq("cooldownLabel exact hour", M.cooldownLabel(3600), "1h")
eq("cooldownLabel hour and change", M.cooldownLabel(3900), "1h 5m")
eq("cooldownLabel zero", M.cooldownLabel(0), "")

eq("formatCount", M.formatCount(1204891), "1,204,891")
eq("formatCount small", M.formatCount(42), "42")
eq("country set accepts unique country codes", M.countrySet("PL\nSE\nPL\njunk\n"), { PL: true, SE: true })
eq("country set merges local history", M.countrySet("JP", { PL: true }), { PL: true, JP: true })
const countries = M.addCountry({ PL: true }, "se")
eq("country set adds a received origin", countries, { PL: true, SE: true })
eq("country count", M.countryCount(countries), 2)
eq("country set ignores private origins", M.addCountry(countries, "??"), countries)

eq("backoffMs first attempt", M.backoffMs(0), 1000)
eq("backoffMs grows", M.backoffMs(4), 16000)
eq("backoffMs caps", M.backoffMs(M.SLOW_RETRY_AFTER - 1), 60000)
eq("backoffMs slows once the relay looks gone", [M.backoffMs(M.SLOW_RETRY_AFTER), M.backoffMs(99)], [M.SLOW_RETRY_MS, M.SLOW_RETRY_MS])
eq("backoffMs slow tail still jitters", M.backoffMs(99, 0), M.SLOW_RETRY_MS / 2)

// --- batons ---
const NOW = Date.parse("2026-09-04T18:00:00Z")
const ago = (ms) => new Date(NOW - ms).toISOString()
const MIN = 60000, HOUR = 60 * MIN, DAY = 24 * HOUR

eq("ageLabel minutes", M.ageLabel(ago(5 * MIN), NOW), "5 minutes")
eq("ageLabel singular hour", M.ageLabel(ago(HOUR), NOW), "1 hour")
eq("ageLabel days", M.ageLabel(ago(3 * DAY), NOW), "3 days")
eq("ageLabel rounds to weeks past a fortnight", M.ageLabel(ago(21 * DAY), NOW), "3 weeks")
eq("ageLabel months", M.ageLabel(ago(200 * DAY), NOW), "6 months")
eq("ageLabel brand new", M.ageLabel(ago(10), NOW), "just now")
eq("ageLabel unparseable", M.ageLabel("not a date", NOW), "")

eq("batonLabel full", M.batonLabel({ hops: 412, born: ago(21 * DAY), countries: 23 }, NOW),
  "412 hops \u00b7 alive 3 weeks \u00b7 23 countries")
eq("batonLabel singulars", M.batonLabel({ hops: 1, born: ago(HOUR), countries: 1 }, NOW),
  "1 hop \u00b7 alive 1 hour \u00b7 1 country")
eq("batonLabel freshly minted has no countries yet", M.batonLabel({ hops: 1, born: ago(10), countries: 0 }, NOW),
  "1 hop \u00b7 born just now")
eq("batonLabel absent", M.batonLabel(null, NOW), "")

eq("deadline survives sleep", M.remainingSeconds(M.cooldownDeadline(3600, NOW), NOW + 3600000), 0)
eq("deadline rounds up", M.remainingSeconds(NOW + 1001, NOW), 2)
eq("invalid cooldown", M.cooldownDeadline(Infinity, NOW), NOW)
eq("absurd cooldown is capped at a day", M.remainingSeconds(M.cooldownDeadline(1e12, NOW), NOW), M.MAX_COOLDOWN_SECONDS)
eq("negative cooldown is zero", M.cooldownDeadline(-5, NOW), NOW)
eq("jitter lower bound", M.backoffMs(3, 0), 4000)
eq("jitter upper bound", M.backoffMs(3, 1), 8000)
eq("baton link", M.batonUrl("https://relay.example/", { id: "a/b" }), "https://relay.example/b/a%2Fb")
eq("invite without identity", M.inviteText("https://relay.example", null, NOW), "Wave at a random Omarchy user, somewhere in the world. Put a wave in your Omarchy bar. https://relay.example/")
// --- settings and timers ---
eq("asBool real booleans pass through", [M.asBool(true, false), M.asBool(false, true)], [true, false])
eq("asBool accepts what `omarchy bar set` stores", [M.asBool("true", false), M.asBool("false", true), M.asBool(" Yes ", false), M.asBool("0", true)], [true, false, true, false])
eq("asBool falls back on junk", [M.asBool("maybe", true), M.asBool(undefined, false), M.asBool(null, true)], [true, false, true])
eq("tickMs counts seconds under a minute", M.tickMs(45), 1000)
eq("tickMs lands on the next minute boundary", [M.tickMs(3583), M.tickMs(120), M.tickMs(61)], [43000, 60000, 1000])
eq("tickMs idles slowly with no cooldown", M.tickMs(0), 60000)

// --- updates ---
const manifest = JSON.parse(fs.readFileSync(path.join(__dirname, "..", "manifest.json"), "utf8"))
eq("VERSION matches manifest.json", M.VERSION, manifest.version)
eq("PLUGIN_ID matches manifest.json", M.PLUGIN_ID, manifest.id)
eq("versionBefore behind", M.versionBefore("0.3.2", "0.4.0"), true)
eq("versionBefore equal", M.versionBefore("0.4.0", "0.4.0"), false)
eq("versionBefore ahead", M.versionBefore("0.10.0", "0.9.9"), false)
eq("versionBefore short segments count as zero", [M.versionBefore("0.4", "0.4.0"), M.versionBefore("0.4", "0.4.1")], [false, true])
eq("versionBefore no floor is never behind", [M.versionBefore("0.4.0", ""), M.versionBefore("0.4.0", undefined), M.versionBefore("0.4.0", "v1"), M.versionBefore("0.4.0", "1.0-rc1")], [false, false, false, false])
eq("versionBefore bad current is never behind", M.versionBefore("", "9.9.9"), false)
// Card priority: errors and in-flight requests must win over old happy events.
const ready = { connected: true, canWave: true, countryNames: C.NAMES }
const card = (extra) => M.cardState(Object.assign({}, ready, extra))
eq("card ready", card({}).key, "ready")
eq("card connection beats delivery", card({ connected: false, lastEvent: "delivered" }).key, "offline")
eq("card identity error", card({ identityError: true }).key, "identity")
eq("card stale beats readiness", card({ stale: true }).key, "stale")
eq("card pending beats incoming", card({ pending: true, lastEvent: "received" }).key, "sending")
eq("card private incoming", card({ lastEvent: "received", lastOrigin: "??" }).title, "Someone, somewhere")
eq("card incoming baton", card({ lastEvent: "received-baton", lastOrigin: "PL" }).key, "received")
eq("card orphan baton", card({ lastEvent: "handed", baton: {} }).title, "A baton found you")
eq("card expired orphan ownership", card({ lastEvent: "handed" }).key, "ready")
eq("card handoff confirmation", card({ lastEvent: "passed" }).key, "delivered")
eq("card empty room beats holding", card({ nobodyAround: true, baton: {}, cooldownRemaining: 45 }).key, "empty")
eq("card holding while cooling", card({ baton: {}, cooldownRemaining: 45 }).key, "baton")
eq("card generic cooldown", card({ cooldownRemaining: 45 }).key, "cooldown")
eq("card pass action", M.cardAction({ connected: true, baton: {} }), "Pass the baton")
eq("card waiting action", M.cardAction({ connected: true, baton: {}, cooldownRemaining: 45 }), "Next wave in 45s")
eq("card unknown delivery", card({ connected: false, lastEvent: "failed" }).body.includes("couldn’t be confirmed"), true)

console.log(failures === 0 ? "\nall passed" : `\n${failures} failed`)
process.exit(failures === 0 ? 0 : 1)
