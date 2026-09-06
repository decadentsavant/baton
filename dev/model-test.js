// Exercises every pure transform in Model.js without Qt. Run: node dev/model-test.js
const fs = require("fs")
const path = require("path")

const load = (file) => {
  const src = fs.readFileSync(path.join(__dirname, "..", file), "utf8")
  const sandbox = {}
  new Function("exports", src + "\n;Object.assign(exports, typeof NAMES !== 'undefined' ? {NAMES} : {" +
    "parseFrame, flagFor, originLabel, waveHeadline, cooldownLabel, formatCount, tooltipText, backoffMs, ageLabel, batonLabel, cooldownDeadline, remainingSeconds, batonUrl, inviteText, asBool, tickMs})")(sandbox)
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

eq("backoffMs first attempt", M.backoffMs(0), 1000)
eq("backoffMs grows", M.backoffMs(4), 16000)
eq("backoffMs caps", M.backoffMs(99), 60000)

eq("tooltip offline", M.tooltipText({ connected: false }), "Baton — offline")
eq("tooltip ready", M.tooltipText({ connected: true, showCounter: true, globalTotal: 1204891, online: 3847, countryNames: C.NAMES }),
  "Click to wave at an Omarch\n1,204,891 waves sent\n3,847 online now")
eq("tooltip cooling down", M.tooltipText({ connected: true, cooldownRemaining: 1800, lastOrigin: "JP", countryNames: C.NAMES }),
  "Next wave in 30m\nLast wave from Japan")

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

eq("tooltip holding a baton", M.tooltipText({
  connected: true, baton: { hops: 412, born: ago(21 * DAY), countries: 23 }, nowMs: NOW, countryNames: C.NAMES }),
  "Click to pass the baton on\nHolding a baton \u2014 412 hops \u00b7 alive 3 weeks \u00b7 23 countries")

eq("deadline survives sleep", M.remainingSeconds(M.cooldownDeadline(3600, NOW), NOW + 3600000), 0)
eq("deadline rounds up", M.remainingSeconds(NOW + 1001, NOW), 2)
eq("invalid cooldown", M.cooldownDeadline(Infinity, NOW), NOW)
eq("jitter lower bound", M.backoffMs(3, 0), 4000)
eq("jitter upper bound", M.backoffMs(3, 1), 8000)
eq("baton link", M.batonUrl("https://relay.example/", { id: "a/b" }), "https://relay.example/b/a%2Fb")
eq("invite without identity", M.inviteText("https://relay.example", null, NOW), "Wave at a random Omarchy user, somewhere in the world. Put a wave in your Omarchy bar. https://relay.example/")
eq("pending tooltip", M.tooltipText({ connected: true, pending: true }), "Sending a wave…")
eq("tooltip after an empty room", M.tooltipText({ connected: true, cooldownRemaining: 45, nobodyAround: true }),
  "Next wave in 45s\nYour last wave found nobody online")

// --- settings and timers ---
eq("asBool real booleans pass through", [M.asBool(true, false), M.asBool(false, true)], [true, false])
eq("asBool accepts what `omarchy bar set` stores", [M.asBool("true", false), M.asBool("false", true), M.asBool(" Yes ", false), M.asBool("0", true)], [true, false, true, false])
eq("asBool falls back on junk", [M.asBool("maybe", true), M.asBool(undefined, false), M.asBool(null, true)], [true, false, true])
eq("tickMs counts seconds under a minute", M.tickMs(45), 1000)
eq("tickMs lands on the next minute boundary", [M.tickMs(3583), M.tickMs(120), M.tickMs(61)], [43000, 60000, 1000])
eq("tickMs idles slowly with no cooldown", M.tickMs(0), 60000)

console.log(failures === 0 ? "\nall passed" : `\n${failures} failed`)
process.exit(failures === 0 ? 0 : 1)
