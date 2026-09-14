import QtQuick
import Quickshell
import "Baton" as Plugin
import "Baton/Countries.js" as Countries

ShellRoot {
  id: root
  readonly property var cases: [
    { name: "Ready / first visit", data: {} },
    { name: "Incoming hello", data: { lastEvent: "received", lastOrigin: "JP", receivedCountryCount: 1 } },
    { name: "Holding a baton", data: { baton: { hops: 412, countries: 23, born: "2026-08-24T00:00:00Z" } } },
    { name: "Sending", data: { pending: true, canWave: false } },
    { name: "Delivered", data: { lastEvent: "delivered", canWave: false, cooldownRemaining: 3600 } },
    { name: "Passed onward", data: { lastEvent: "passed", canWave: false, cooldownRemaining: 3590 } },
    { name: "Quiet room", data: { nobodyAround: true, canWave: false, cooldownRemaining: 45 } },
    { name: "Cooldown / settings", data: { canWave: false, cooldownRemaining: 1800, lastOrigin: "PL" } },
    { name: "Connection lost", data: { connected: false, canWave: false, lastEvent: "failed" } },
    { name: "Identity error", data: { connected: false, canWave: false, identityError: true, statsKnown: false } },
    { name: "Restart needed", data: { stale: true } },
    { name: "Private hello / update", data: { lastEvent: "received", lastOrigin: "??", outdated: true } }
  ]
  FloatingWindow {
    implicitWidth: 1560
    implicitHeight: 2010
    color: "#111b16"
    Rectangle {
      id: canvas
      anchors.fill: parent
      color: "#111b16"
      Grid {
        x: 20; y: 20
        columns: 4
        spacing: 20
        Repeater {
          model: root.cases
          Rectangle {
            required property var modelData
            required property int index
            width: 365; height: 640
            color: "#19251e"
            Text { x: 14; y: 12; text: modelData.name; color: "#819584"; font.pixelSize: 13 }
            Plugin.BatonCard {
              x: 14; y: 42; width: parent.width - 28
              foreground: "#f1edda"; accent: "#ddf29b"
              settingsOpen: index === 7
              state: Object.assign({ connected: true, canWave: true, statsKnown: true,
                globalTotal: 120491, online: 38, receivedCountryCount: 7,
                nowMs: Date.parse("2026-09-14T12:00:00Z"), countryNames: Countries.NAMES }, modelData.data)
            }
          }
        }
      }
    }
  }
  Timer {
    interval: 1500; running: true
    onTriggered: canvas.grabToImage(function(result) {
      result.saveToFile(Quickshell.env("BATON_CARD_OUTPUT"))
      Qt.quit()
    })
  }
}
