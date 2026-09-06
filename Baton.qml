import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "." as Local
import "Model.js" as Model
import "Countries.js" as Countries

BarWidget {
  id: root
  moduleName: "io.github.decadentsavant.baton"
  readonly property string relayUrl: String(setting("relayUrl", "https://relay.baton.buzz")).replace(/\/+$/, "")
  // `omarchy bar set` stores plain values as strings unless told --json, so a
  // boolean setting may arrive as true or as "true". Both mean yes.
  readonly property bool shareRegion: Model.asBool(setting("shareRegion", true), true)
  readonly property bool soundEnabled: Model.asBool(setting("sound", false), false)
  readonly property bool showCounter: Model.asBool(setting("showCounter", true), true)
  property bool optionsOpen: false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  function configure() { Local.BatonService.configure(relayUrl, shareRegion, soundEnabled) }
  function close() { optionsOpen = false }
  function setShareRegion(value) {
    var entry = Object.assign({}, settings || {})
    entry.id = moduleName
    entry.shareRegion = value
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
  }
  Component.onCompleted: { Local.BatonService.retain(); configure() }
  Component.onDestruction: Local.BatonService.release()
  onRelayUrlChanged: Qt.callLater(configure)
  onShareRegionChanged: Qt.callLater(configure)
  onSoundEnabledChanged: Qt.callLater(configure)
  Connections {
    target: Local.BatonService
    function onReceived() { sent.stop(); handed.stop(); pulse.restart() }
    function onHanded() { sent.stop(); pulse.stop(); handed.restart() }
    function onSent() { pulse.stop(); handed.stop(); sent.restart() }
  }

  // ------------------------------------------------------------------- ui
  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "\uDB86\uDC21" // nf-md-hand_wave, U+F1821
    slotSize: Style.bar.statusSlot
    fontSize: Style.font.caption
    dimmed: !Local.BatonService.canWave
    active: Local.BatonService.baton !== null
    tooltipText: Model.tooltipText({
      connected: Local.BatonService.connected,
      pending: Local.BatonService.pending,
      baton: Local.BatonService.baton,
      nowMs: Local.BatonService.nowMs,
      cooldownRemaining: Local.BatonService.cooldownRemaining,
      nobodyAround: Local.BatonService.nobodyAround,
      lastOrigin: Local.BatonService.lastOrigin,
      globalTotal: Local.BatonService.globalTotal,
      online: Local.BatonService.online,
      showCounter: root.showCounter,
      countryNames: Countries.NAMES
    }) + "\nRight-click: explore batons · Middle-click: options"

    onPressed: function(b) {
      if (b === Qt.RightButton) Util.execArgv(["xdg-open", Model.batonUrl(root.relayUrl, Local.BatonService.baton)])
      else if (b === Qt.MiddleButton) root.optionsOpen = !root.optionsOpen
      else if (b === Qt.LeftButton) Local.BatonService.sendWave()
    }
  }

  PopupCard {
    id: optionsPopup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.optionsOpen
    contentWidth: optionsPopup.fittedContentWidth(Style.space(330))
    contentHeight: optionsPopup.fittedContentHeight(optionsColumn.implicitHeight)

    Column {
      id: optionsColumn
      width: parent.width
      spacing: Style.space(10)

      Text {
        text: "Baton options"
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        width: parent.width
        text: "Country sharing is a simple approximation based on your IP address. It shows a country when on, or “somewhere” when off."
        color: root.bar ? root.bar.barForeground : Color.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Toggle {
        width: parent.width
        label: "Show my country"
        description: root.shareRegion ? "Waves can show your approximate country." : "Waves arrive as “somewhere”."
        checked: root.shareRegion
        foreground: root.bar ? root.bar.barForeground : Color.foreground
        accent: root.bar ? root.bar.urgent : Color.accent
        onClicked: root.setShareRegion(!root.shareRegion)
      }
    }
  }

  // An incoming wave: two quick swells. Deliberately not a popup — the whole
  // premise is that one bit belongs in the periphery, not in your face.
  SequentialAnimation {
    id: pulse
    loops: 2
    NumberAnimation { target: button; property: "scale"; to: 1.35; duration: 140; easing.type: Easing.OutCubic }
    NumberAnimation { target: button; property: "scale"; to: 1.0;  duration: 220; easing.type: Easing.OutBack }
  }

  // An outgoing wave: one small dip, so a click always feels acknowledged even
  // when the relay is slow or the send is about to be rejected.
  SequentialAnimation {
    id: sent
    NumberAnimation { target: button; property: "scale"; to: 0.8; duration: 90 }
    NumberAnimation { target: button; property: "scale"; to: 1.0; duration: 160; easing.type: Easing.OutBack }
  }

  // Being handed an orphan: one slow swell, distinct from the sharp double
  // pulse of someone actually waving at you.
  SequentialAnimation {
    id: handed
    NumberAnimation { target: button; property: "scale"; to: 1.2; duration: 420; easing.type: Easing.InOutSine }
    NumberAnimation { target: button; property: "scale"; to: 1.0; duration: 420; easing.type: Easing.InOutSine }
  }

}
