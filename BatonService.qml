import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model
import "Countries.js" as Countries

// One instance per shell, shared by every monitor's widget. The host creates
// it from the manifest's service entry point and destroys it on every plugin
// reload, which also ends the relay connection cleanly. Before 1.0.2 this was
// a qmldir singleton, which outlived reloads.
//
// A reload does not load new code: the shell re-instantiates plugins from
// its cached compile, so an update only runs after a shell restart. What a
// reload does refresh is the manifest, which the host reads from disk and
// injects here. Comparing its version with the one compiled into Model.js
// tells the widget that an update is installed but not yet running.
Scope {
  id: root
  readonly property string version: Model.VERSION
  // Injected by the host on creation, from the manifest.json on disk.
  property var manifest: null
  readonly property string installedVersion: manifest && typeof manifest.version === "string" ? manifest.version : ""
  readonly property bool stale: installedVersion !== "" && installedVersion !== Model.VERSION
  readonly property string glyph: "\uDB86\uDC21" // nf-md-hand_wave, U+F1821
  property string relayUrl: "https://relay.baton.buzz"
  property bool shareRegion: true
  property bool soundEnabled: false
  property bool configured: false
  property int widgetCount: 0
  property string identity: ""
  property bool connected: false
  property bool pending: false
  property bool replyReceived: false
  property int generation: 0
  property int waveGeneration: 0
  property int streamGeneration: 0
  property int reconnectAttempt: 0
  property double globalTotal: 0
  property int online: 0
  property string lastOrigin: ""
  property bool nobodyAround: false
  property var baton: null
  property double nowMs: Date.now()
  property double readyAt: 0
  property string minClient: ""
  property bool updateNotified: false
  property bool identityError: false
  // True once the relay has been out of reach long enough that the backoff
  // has settled into its slow tail; the tooltip says so instead of "offline".
  readonly property bool unreachable: reconnectAttempt >= Model.SLOW_RETRY_AFTER
  readonly property bool outdated: Model.versionBefore(Model.VERSION, minClient)
  readonly property int cooldownRemaining: Model.remainingSeconds(readyAt, nowMs)
  readonly property bool canWave: connected && !pending && identity !== "" && cooldownRemaining === 0
  signal received()
  signal handed()
  signal sent()

  Component.onCompleted: console.log("Baton: service " + Model.VERSION + " started")
  onConnectedChanged: if (root.connected) console.log("Baton: connected to " + root.relayUrl)
  // Once per instance. The host recreates the service on every reload, so a
  // user who updates and keeps working hears this once per update, not once
  // per bar tick; the tooltip carries the hint until the restart.
  onStaleChanged: {
    if (!root.stale) return
    console.log("Baton: " + root.installedVersion + " is installed but " + Model.VERSION + " is running; restart the shell")
    Util.execArgv(["omarchy-notification-send", "--app-name", "Baton", "-u", "low", "-g", root.glyph,
      "Baton " + root.installedVersion + " is installed", "The bar is still running " + Model.VERSION + ". Run: " + Model.RESTART_COMMAND])
  }
  // The host destroys this instance on reload. QProcess would kill the children
  // on its own, but stopping them here keeps the teardown explicit and quiet.
  Component.onDestruction: {
    reconnectTimer.stop()
    heartbeat.stop()
    streamProc.running = false
    waveProc.running = false
  }

  function retain() { root.widgetCount++ }
  function release() {
    root.widgetCount = Math.max(0, root.widgetCount - 1)
    if (root.widgetCount !== 0) return
    root.configured = false
    root.connected = false
    root.generation++
    reconnectTimer.stop()
    heartbeat.stop()
    streamProc.running = false
    waveProc.running = false
    root.baton = null
    root.nobodyAround = false
    root.readyAt = 0
    root.minClient = ""
  }

  // Once per session, and only when a relay actually says so. The tooltip
  // keeps the hint for as long as the widget stays behind.
  onOutdatedChanged: {
    if (!root.outdated || root.updateNotified) return
    root.updateNotified = true
    Util.execArgv(["omarchy-notification-send", "--app-name", "Baton", "-u", "low", "-g", root.glyph,
      "Baton has an update", "The relay supports Baton " + root.minClient + " or newer. Run: " + Model.UPDATE_COMMAND])
  }

  // The chime ships with the plugin, next to this file, so it is the same on
  // every install. Qt.resolvedUrl keeps the plugin directory even though the
  // shell runs from a cached compile. mpv is an Omarchy base package and is
  // what Omarchy's own hooks play sounds with. Without it, pw-play from the
  // PipeWire stack Omarchy runs on plays the file; it decodes MP3 through
  // libsndfile. Neither opens a window. The desktop theme's message sound is
  // the last resort.
  readonly property string chimePath: {
    var url = String(Qt.resolvedUrl("omarchy.mp3"))
    return url.indexOf("file://") === 0 ? decodeURIComponent(url.slice(7)) : ""
  }
  function chime() {
    if (root.chimePath === "")
      Util.execArgv(["canberra-gtk-play", "-i", "message-new-instant"])
    else
      Util.execArgv(["bash", "-c", 'if command -v mpv >/dev/null 2>&1; then exec mpv --no-video --really-quiet --no-config -- "$1"; fi; ' +
        'if command -v pw-play >/dev/null 2>&1; then exec pw-play -- "$1"; fi; ' +
        'exec canberra-gtk-play -i message-new-instant', "baton-chime", root.chimePath])
  }

  function configure(url, share, sound) {
    if (root.widgetCount === 0) return
    var changed = root.relayUrl !== url
    root.shareRegion = share
    root.soundEnabled = sound
    root.configured = true
    if (changed) {
      root.relayUrl = url
      root.generation++
      root.baton = null
      root.lastOrigin = ""
      root.nobodyAround = false
      root.globalTotal = 0
      root.online = 0
      root.readyAt = 0
      root.minClient = ""
      if (waveProc.running) waveProc.running = false
      reconnect()
    } else if (root.identity !== "" && !streamProc.running && !reconnectTimer.running) {
      root.startStream()
    }
  }

  function startStream() {
    root.streamGeneration = root.generation
    streamProc.running = true
  }

  function reconnect() {
    root.connected = false
    heartbeat.stop()
    reconnectTimer.stop()
    if (streamProc.running) streamProc.running = false
    else { reconnectTimer.interval = 1; reconnectTimer.start() }
  }

  Process {
    id: identityProc
    running: true
    // flock also makes simultaneous first starts in separate shells safe. A
    // file that does not hold one usable token (truncated, hand-edited, or
    // corrupted) is replaced rather than left to disable the widget forever;
    // the token was unusable anyway, so nothing of value is lost.
    command: ["bash", "-c", "set -euo pipefail; export LC_ALL=C; umask 077; d=\"${XDG_STATE_HOME:-$HOME/.local/state}/baton\"; mkdir -p \"$d\"; exec 9>\"$d/id.lock\"; flock 9; f=\"$d/id\"; id=$(head -c 66 \"$f\" 2>/dev/null | head -n 1 || true); if ! [[ $id =~ ^[A-Za-z0-9_-]{8,64}$ ]]; then head -c 16 /dev/urandom | base32 | tr -d '=\\n' > \"$f.tmp\"; mv \"$f.tmp\" \"$f\"; id=$(cat \"$f\"); fi; printf '%s\\n' \"$id\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var id = String(this.text || "").trim()
        if (!/^[A-Za-z0-9_-]{8,64}$/.test(id)) {
          root.identityError = true
          console.warn("Baton: could not create an identity in ${XDG_STATE_HOME:-~/.local/state}/baton; check that the directory is writable")
          return
        }
        root.identityError = false
        root.identity = id
        if (root.configured) root.startStream()
      }
    }
  }

  // Both relay paths go through a byte ceiling before anything reaches the
  // shell. SplitParser and StdioCollector buffer whatever curl hands them, so
  // a relay that never sends a newline, or never stops sending, would grow the
  // bar's memory until something else gave out. Legitimate frames are well
  // under 1 KiB and the stream carries a few bytes a second, so the caps below
  // are generous for a healthy relay and fatal for a hostile one: the filter
  // exits, curl is killed, and the usual reconnect backoff takes over.
  readonly property int maxLineBytes: Model.MAX_FRAME_CHARS
  readonly property int maxStreamBytes: 1048576
  // `head -c` is the per-connection ceiling. `fold -b` never holds more than
  // one line width in memory, so a line that never ends reaches sed as full
  // width chunks, and sed quits with an error on the first one; a real frame
  // is far shorter and passes through untouched. Every stage is C, so a
  // flooding relay costs a few milliseconds before a cap trips, not a busy
  // core. sed is the foreground command and the other stages feed it from a
  // process substitution, so the moment sed quits the script exits, the trap
  // kills curl, and head and fold end on EOF; a plain pipeline would instead
  // wait for head, which may be blocked on a relay that has gone quiet.
  // Buffering matters on a live stream: head and fold buffer when writing to
  // a pipe, so stdbuf makes them stream, and sed runs unbuffered. Without
  // that, frames would sit in a 4 KiB buffer for half an hour before the bar
  // saw them. sed rather than awk because mawk fills its input buffer before
  // it processes a line, and there is no telling which awk a machine has.
  // LC_ALL=C makes fold and sed count bytes rather than characters.
  readonly property string streamScript: "export LC_ALL=C; " +
    "exec 3< <(exec curl -fsSN --connect-timeout 10 --speed-limit 1 --speed-time 75 -H \"X-Baton-Id: $1\" -- \"$2/stream\"); pid=$!; " +
    "trap 'kill \"$pid\" 2>/dev/null' EXIT; " +
    "sed -u \"/^.\\\\{$3\\\\}/Q66\" < <(stdbuf -o0 head -c \"$4\" <&3 | stdbuf -oL fold -b -w \"$3\")"

  Process {
    id: streamProc
    command: ["bash", "-c", root.streamScript, "baton-stream", root.identity, root.relayUrl,
      String(root.maxLineBytes), String(root.maxStreamBytes)]
    stdout: SplitParser {
      onRead: function(line) { root.handleFrame(line) }
    }
    onExited: {
      root.connected = false
      heartbeat.stop()
      if (!root.configured) return
      reconnectTimer.interval = Model.backoffMs(root.reconnectAttempt, Math.random())
      root.reconnectAttempt++
      reconnectTimer.restart()
    }
  }
  Timer {
    id: reconnectTimer
    onTriggered: if (root.configured && root.identity !== "" && !streamProc.running) root.startStream()
  }
  Timer {
    id: heartbeat
    interval: 75000
    onTriggered: root.reconnect()
  }

  function handleFrame(line) {
    if (root.streamGeneration !== root.generation) return
    var frame = Model.parseFrame(line)
    if (!frame) return
    heartbeat.restart()
    root.nowMs = Date.now()
    if (frame.type === "state") {
      root.baton = frame.baton || null
      root.readyAt = Model.cooldownDeadline(frame.remaining, root.nowMs)
      root.minClient = typeof frame.minClient === "string" ? frame.minClient : ""
      root.connected = true
      root.reconnectAttempt = 0
    } else if (frame.type === "wave") {
      root.lastOrigin = String(frame.origin || "")
      root.nobodyAround = false
      if (frame.baton) root.baton = frame.baton
      root.received()
      var body = frame.baton ? "passed you a baton — " + Model.batonLabel(frame.baton, root.nowMs) : "waved at you"
      Util.execArgv(["omarchy-notification-send", "--app-name", "Baton", "-u", "low", "-g", root.glyph,
        Model.waveHeadline(root.lastOrigin, Countries.NAMES), body])
      if (root.soundEnabled) root.chime()
    } else if (frame.type === "baton") {
      root.baton = frame.baton || null
      root.handed()
    } else if (frame.type === "stats") {
      root.globalTotal = Math.max(0, Number(frame.total) || 0)
      root.online = Math.max(0, Number(frame.online) || 0)
    }
  }

  // The reply is one small JSON object. `head -c` is a hard ceiling on what
  // StdioCollector can accumulate, chunked or not. Past it the text is cut
  // mid-object and fails to parse, so replyReceived stays false and onExited
  // treats the wave as failed; once the excess outgrows the pipe buffer curl
  // also takes a write error, which pipefail surfaces as a non-zero exit.
  readonly property string waveScript: "set -o pipefail; " +
    "curl -fsS --max-time 8 -X POST -H \"X-Baton-Id: $1\" -H \"X-Baton-Share-Region: $2\" -- \"$3/wave\" | head -c \"$4\""

  Process {
    id: waveProc
    command: ["bash", "-c", root.waveScript, "baton-wave", root.identity, (root.shareRegion ? "1" : "0"), root.relayUrl,
      String(root.maxLineBytes)]
    stdout: StdioCollector {
      onStreamFinished: {
        if (root.waveGeneration !== root.generation) return
        var frame = Model.parseFrame(this.text)
        if (!frame || frame.type !== "cooldown") return
        root.replyReceived = true
        root.nowMs = Date.now()
        root.readyAt = Model.cooldownDeadline(frame.remaining, root.nowMs)
        // Ownership only comes from the ordered stream. An old POST reply
        // must never clear a baton that arrived while the request was running.
        if (frame.delivered === false) {
          // An empty room. Say so, or the click looks like it did nothing.
          root.nobodyAround = true
          Util.execArgv(["omarchy-notification-send", "--app-name", "Baton", "-u", "low", "-g", root.glyph,
            "Nobody's around right now", "Your wave found an empty room. Try again in " + Model.cooldownLabel(root.cooldownRemaining) + "."])
        }
      }
    }
    onExited: function(exitCode) {
      Qt.callLater(function() {
        root.pending = false
        if (root.waveGeneration === root.generation && (exitCode !== 0 || !root.replyReceived)) root.reconnect()
      })
    }
  }
  function sendWave() {
    if (!root.canWave || waveProc.running) return
    root.pending = true
    root.nobodyAround = false
    root.replyReceived = false
    root.waveGeneration = root.generation
    root.sent()
    waveProc.running = true
  }

  // Wall time survives suspend; one shared timer also refreshes baton age. It
  // ticks only as often as the label can change: every second under a minute,
  // once a minute above it.
  Timer {
    interval: Model.tickMs(root.cooldownRemaining)
    running: root.baton !== null || root.readyAt > 0
    repeat: true
    onTriggered: { root.nowMs = Date.now(); if (root.cooldownRemaining === 0) root.readyAt = 0 }
  }

  IpcHandler {
    target: "baton"
    function wave(): void { root.sendWave() }
    function invite(): void { root.copyInvite() }
  }
  function copyInvite() {
    if (copyProc.running) return
    copyProc.command = ["wl-copy", "--", Model.inviteText(root.relayUrl, root.baton, Date.now())]
    copyProc.running = true
  }
  Process {
    id: copyProc
    onExited: function(exitCode) {
      if (exitCode === 0) Util.execArgv(["omarchy-notification-send", "--app-name", "Baton", "-u", "low", "Invite copied", "Ready to share when you are."])
    }
  }
}
