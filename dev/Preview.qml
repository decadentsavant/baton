import QtQuick
import Quickshell
import "Baton" as Plugin
import "Baton/Model.js" as Model

ShellRoot {
  id: root
  // Frames, rather than wall-clock sleeps, set the reading time in the video.
  readonly property int fps: 20
  readonly property var phaseSeconds: [4, 8, 4, 6, 5]
  property int phase: 0
  property int phaseFrame: 0
  property int frame: 0
  property int receivedCount: 0
  property bool receivedBaton: false
  property bool retainedBaton: false
  property bool waiting: false
  property bool capturing: false
  property bool finished: false
  readonly property string ink: "#f1edda"
  readonly property string secondary: "#aab5a7"
  readonly property string lime: "#ddf29b"
  readonly property var titles: ["A small hello, in your bar.", "Someone in Poland waved.", "The baton stays with you.", "Your wave passes it on.", "One bit out. One bit back."]
  readonly property var bodies: ["No account. No message to compose.\nJust another Omarchy user, somewhere.", "They passed you a baton.\nIts story is only hops, age, and countries.", "Another hello arrives.\nYou keep the baton until you pass it on.", "One click sends your hello onward.\nThe baton is now in someone else’s hands.", "No names. No messages.\nJust a hello from another desktop."]

  FloatingWindow {
    implicitWidth: 1280
    implicitHeight: 760
    color: "#111b16"
    Rectangle {
      id: canvas
      anchors.fill: parent
      color: "#111b16"
      Text { x: 60; y: 42; text: "baton"; color: root.lime; font.pixelSize: 30; font.bold: true }
      Text { x: 60; y: 109; text: "Someone’s out there."; color: root.ink; font.pixelSize: 58 }
      Text { x: 63; y: 191; text: "Wave at a random Omarchy user, somewhere in the world."; color: root.secondary; font.pixelSize: 23 }

      Rectangle {
        x: 60; y: 270; width: 1160; height: 300; radius: 12; color: "#26372b"
        Rectangle {
          x: 0; y: 0; width: 300; height: 300; radius: 12; color: "#1d2c22"
          Text { anchors.horizontalCenter: parent.horizontalCenter; y: 27; text: "YOUR BAR WIDGET"; color: root.secondary; font.pixelSize: 12; font.letterSpacing: 2 }
          Loader {
            id: firstWidget
            anchors.centerIn: parent
            scale: 7
            sourceComponent: Plugin.Baton { settings: ({relayUrl:Quickshell.env("BATON_PREVIEW_RELAY")}) }
          }
          Text { anchors.horizontalCenter: parent.horizontalCenter; y: 256; text: "ACTUAL WIDGET · 7× DETAIL"; color: root.secondary; font.pixelSize: 11; font.letterSpacing: 1 }
          Rectangle {
            anchors.centerIn: parent; width: 150; height: 150; radius: 75
            color: "transparent"; border.color: root.lime; border.width: 2
            visible: root.phase === 3 && root.phaseFrame < root.fps * 2
          }
        }
        Text { x: 340; y: 35; text: ["01 / READY", "02 / A WAVE ARRIVES", "03 / HOLDING THE BATON", "04 / PASSED ON", "05 / THAT’S BATON"][root.phase]; color: root.lime; font.pixelSize: 13; font.letterSpacing: 1.5 }
        Text { x: 340; y: 80; text: root.titles[root.phase]; color: root.ink; font.pixelSize: 32 }
        Text { x: 342; y: 139; text: root.bodies[root.phase]; color: root.ink; font.pixelSize: 23; lineHeight: 1.35 }
        Text {
          x: 342; y: 246
          text: root.phase === 1 || root.phase === 2 ? "1 hop · born just now · 1 country" : root.phase === 3 ? "Wave sent. Baton passed." : "One wave an hour on the public relay."
          color: root.lime; font.pixelSize: 17
        }
      }
      Loader {
        id: secondWidget
        visible: false
        sourceComponent: Plugin.Baton { settings: ({relayUrl:Quickshell.env("BATON_PREVIEW_RELAY")}) }
      }
      Row {
        x: 60; y: 618; spacing: 12
        Repeater {
          model: 5
          Rectangle { required property int index; width: 222; height: 3; color: index <= root.phase ? root.lime : "#304036" }
        }
      }
      Text { x: 61; y: 650; text: "No names. No messages. Just a hello."; color: root.ink; font.pixelSize: 23 }
      Text { x: 62; y: 707; text: "LOCAL DEMO · REAL WIDGET + RELAY · ENLARGED DETAIL · EXPLANATORY CAPTIONS"; color: root.secondary; font.pixelSize: 11; font.letterSpacing: 1 }
    }
  }

  function enterPhase(next) { root.phase = next; root.phaseFrame = 0; root.waiting = false }
  Connections {
    target: Plugin.BatonService
    function onReceived() {
      root.receivedCount++
      if (root.receivedCount === 1) {
        root.receivedBaton = Plugin.BatonService.baton !== null
        root.enterPhase(1)
      } else {
        root.retainedBaton = Plugin.BatonService.baton !== null
        root.enterPhase(2)
      }
    }
  }
  function passBaton() {
    // Exercise the actual widget's left-click handler, without moving the user's mouse.
    var items = firstWidget.item.children
    for (var i = 0; i < items.length; i++) {
      if (typeof items[i].triggerPress === "function") { items[i].triggerPress(Qt.LeftButton); return }
    }
    throw new Error("No widget click target")
  }
  function advance() {
    root.capturing = false
    root.frame++
    root.phaseFrame++
    if (root.phaseFrame < root.phaseSeconds[root.phase] * root.fps) return
    if (root.phase === 0) { root.waiting = true; console.log("PREVIEW_WAVE1") }
    else if (root.phase === 1) { root.waiting = true; console.log("PREVIEW_WAVE2") }
    else if (root.phase === 2) { root.waiting = true; root.passBaton() }
    else if (root.phase === 3) root.enterPhase(4)
    else {
      root.finished = true
      console.log("BATON_CHECK " + JSON.stringify({connected:Plugin.BatonService.connected,received:root.receivedBaton,retained:root.retainedBaton,passed:Plugin.BatonService.baton === null,pending:Plugin.BatonService.pending}))
      firstWidget.active = false
      secondWidget.active = false
      releaseTimer.start()
    }
  }
  Timer {
    interval: 50; running: !root.finished; repeat: true
    onTriggered: {
      if (root.capturing || !Plugin.BatonService.connected) return
      if (root.waiting) {
        if (root.phase === 2 && Plugin.BatonService.baton === null && !Plugin.BatonService.pending) root.enterPhase(3)
        else return
      }
      root.capturing = true
      var path = Quickshell.env("BATON_PREVIEW_FRAMES") + "/frame-" + String(root.frame + 1).padStart(4,"0") + ".png"
      canvas.grabToImage(function(result) {
        if (!result.saveToFile(path)) throw new Error("Could not save " + path)
        root.advance()
      })
    }
  }
  Timer {
    id: releaseTimer; interval: 1000
    onTriggered: {
      console.log("BATON_RELEASE " + JSON.stringify({widgets:Plugin.BatonService.widgetCount,connected:Plugin.BatonService.connected}))
      Qt.quit()
    }
  }
  Timer { interval: 300000; running: true; onTriggered: { console.log("PREVIEW_TIMEOUT"); Qt.quit() } }
}
