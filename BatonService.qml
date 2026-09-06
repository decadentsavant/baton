pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model
import "Countries.js" as Countries

// One connection per QML engine, shared by every monitor's widget.
Scope {
  id: root
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
  readonly property bool outdated: Model.versionBefore(Model.VERSION, minClient)
  readonly property int cooldownRemaining: Model.remainingSeconds(readyAt, nowMs)
  readonly property bool canWave: connected && !pending && identity !== "" && cooldownRemaining === 0
  signal received()
  signal handed()
  signal sent()

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
    // flock also makes simultaneous first starts in separate shells safe.
    command: ["bash", "-c", "set -euo pipefail; umask 077; d=\"${XDG_STATE_HOME:-$HOME/.local/state}/baton\"; mkdir -p \"$d\"; exec 9>\"$d/id.lock\"; flock 9; f=\"$d/id\"; if [ ! -s \"$f\" ]; then head -c 16 /dev/urandom | base32 | tr -d '=\\n' > \"$f.tmp\"; mv \"$f.tmp\" \"$f\"; fi; cat \"$f\""]
    stdout: StdioCollector {
      onStreamFinished: {
        var id = String(this.text || "").trim()
        if (!/^[A-Za-z0-9_-]{8,64}$/.test(id)) {
          console.warn("Baton: no usable identity in ${XDG_STATE_HOME:-~/.local/state}/baton/id; delete the file to mint a new one")
          return
        }
        root.identity = id
        if (root.configured) root.startStream()
      }
    }
  }

  Process {
    id: streamProc
    command: ["curl", "-fsSN", "--connect-timeout", "10", "--speed-limit", "1", "--speed-time", "75",
      "-H", "X-Baton-Id: " + root.identity, root.relayUrl + "/stream"]
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
      if (root.soundEnabled) Util.execArgv(["canberra-gtk-play", "-i", "message-new-instant"])
    } else if (frame.type === "baton") {
      root.baton = frame.baton || null
      root.handed()
    } else if (frame.type === "stats") {
      root.globalTotal = Math.max(0, Number(frame.total) || 0)
      root.online = Math.max(0, Number(frame.online) || 0)
    }
  }

  Process {
    id: waveProc
    command: ["curl", "-fsS", "--max-time", "8", "-X", "POST",
      "-H", "X-Baton-Id: " + root.identity,
      "-H", "X-Baton-Share-Region: " + (root.shareRegion ? "1" : "0"), root.relayUrl + "/wave"]
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
