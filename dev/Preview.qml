import QtQuick
import Quickshell
import Quickshell.Io
import "Baton" as Plugin
import "Baton/Model.js" as Model

ShellRoot {
  id: root
  FloatingWindow {
    id: window
    title: "Baton — local preview"
    implicitWidth: 1040
    implicitHeight: 620
    color: "#111b16"
    Rectangle {
      id: canvas
      anchors.fill: parent
      color: "#111b16"
      Text { x: 55; y: 45; text: "baton"; color: "#ddf29b"; font.pixelSize: 28; font.bold: true }
      Text { x: 55; y: 106; text: "Someone’s out there."; color: "#f1edda"; font.pixelSize: 52 }
      Text { x: 58; y: 185; text: "One bit out. One bit back."; color: "#aab5a7"; font.pixelSize: 20 }
      Rectangle {
        x: 55; y: 267; width: 930; height: 48; radius: 8; color: "#26372b"
        Text { x: 20; anchors.verticalCenter: parent.verticalCenter; text: "◉     1   2   3"; color: "#aab5a7"; font.pixelSize: 15 }
        Text { anchors.centerIn: parent; text: "YOUR OMARCHY BAR"; color: "#aab5a7"; font.pixelSize: 11; font.letterSpacing: 2 }
        Loader {
          id: firstWidget
          anchors.right: parent.right
          anchors.rightMargin: 22
          anchors.verticalCenter: parent.verticalCenter
          sourceComponent: Plugin.Baton { settings: ({relayUrl:Quickshell.env("BATON_PREVIEW_RELAY")}) }
        }
        Loader {
          id: secondWidget
          visible: false
          sourceComponent: Plugin.Baton { settings: ({relayUrl:Quickshell.env("BATON_PREVIEW_RELAY")}) }
        }
      }
      Rectangle {
        x: 535; y: 343; width: 450; height: 120; radius: 8; color: "#26372b"
        Text { x: 24; y: 20; text: Plugin.BatonService.lastOrigin ? "Someone in Poland" : "A wave is on its way"; color: "#f1edda"; font.pixelSize: 22 }
        Text { x: 24; y: 60; text: Plugin.BatonService.baton ? "passed you a baton · " + Model.batonLabel(Plugin.BatonService.baton, Date.now()) : "A small hello from another desktop."; color: "#ddf29b"; font.pixelSize: 16 }
      }
      Text { x: 55; y: 522; text: "No names. No messages. Just a hello."; color: "#f1edda"; font.pixelSize: 22 }
      Text { x: 57; y: 565; text: "LOCAL DEMO · LIVE WIDGET + RELAY · ILLUSTRATIVE NOTIFICATION"; color: "#aab5a7"; font.pixelSize: 10; font.letterSpacing: 1.4 }
    }
  }
  property int tick: 0
  property bool receivedBaton: false
  property bool retainedBaton: false
  Connections {
    target: Plugin.BatonService
    function onReceived() {
      if (root.receivedBaton) root.retainedBaton = Plugin.BatonService.baton !== null
      root.receivedBaton = Plugin.BatonService.baton !== null
    }
  }
  Timer {
    interval: 100
    running: true
    repeat: true
    onTriggered: {
      root.tick++
      if (root.tick === 95) Plugin.BatonService.sendWave()
      if (root.tick <= 140) {
        var path = Quickshell.env("BATON_PREVIEW_FRAMES") + "/frame-" + String(root.tick).padStart(4, "0") + ".png"
        canvas.grabToImage(function(result) { result.saveToFile(path) })
      }
      if (root.tick === 145) {
        console.log("BATON_CHECK " + JSON.stringify({connected:Plugin.BatonService.connected, received:root.receivedBaton, retained:root.retainedBaton, passed:Plugin.BatonService.baton === null, pending:Plugin.BatonService.pending}))
        firstWidget.active = false
        secondWidget.active = false
      }
      if (root.tick === 155) {
        console.log("BATON_RELEASE " + JSON.stringify({widgets:Plugin.BatonService.widgetCount, connected:Plugin.BatonService.connected}))
        Qt.quit()
      }
    }
  }
}
