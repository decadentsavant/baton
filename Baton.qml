import QtQuick
import Quickshell
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Countries.js" as Countries

BarWidget {
  id: root
  moduleName: "io.github.decadentsavant.baton"
  readonly property string relayUrl: String(setting("relayUrl", "https://relay.baton.buzz")).replace(/\/+$/, "")
  // `omarchy bar set` stores plain values as strings unless told --json, so a
  // boolean setting may arrive as true or as "true". Both mean yes.
  readonly property bool shareRegion: Model.asBool(setting("shareRegion", true), true)
  readonly property bool soundEnabled: Model.asBool(setting("sound", true), true)
  readonly property bool showCounter: Model.asBool(setting("showCounter", true), true)
  readonly property color foreground: root.bar ? root.bar.barForeground : Color.foreground
  readonly property color accent: root.bar ? root.bar.urgent : Color.accent
  property bool optionsOpen: false
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  // The shared BatonService instance. The host creates one per shell from the
  // manifest's service entry and replaces it on every plugin reload, so its
  // relay connection ends with it. The widget asks the host for it rather than
  // importing a singleton, which a reload would not replace. A harness without
  // a bar (dev/Preview.qml) sets it directly.
  property var service: null
  property var retainedService: null
  property int serviceTries: 0
  readonly property int serviceTryLimit: 20
  // svc is always an object, so bindings stay valid while the service is
  // missing; every read is then undefined, which the tooltip treats as idle.
  readonly property var svc: root.service || ({})
  // An update is installed but not running (the service reads the version on
  // disk), or the host never produced a service at all. A restart fixes both.
  readonly property bool stale: root.svc.stale === true || (root.service === null && root.serviceTries >= root.serviceTryLimit)

  function lookupService() {
    return bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell.serviceFor(moduleName) : null
  }
  function bindService() {
    var next = lookupService() || root.service
    if (next !== root.retainedService) {
      if (root.retainedService) root.retainedService.release()
      root.retainedService = next
      root.service = next
      if (next) {
        next.retain()
        configure()
        console.log("Baton: widget " + Model.VERSION + " bound to service " + (next.version || "before 1.0.2"))
      }
    }
  }
  function configure() { if (root.service) root.service.configure(relayUrl, shareRegion, soundEnabled) }
  function close() { optionsOpen = false }
  function setSetting(key, value) {
    var entry = Object.assign({}, settings || {})
    entry.id = moduleName
    entry[key] = value
    if (bar && bar.shell && typeof bar.shell.updateEntryInline === "function")
      bar.shell.updateEntryInline(moduleName, entry)
  }
  Component.onCompleted: bindService()
  Component.onDestruction: if (root.retainedService) root.retainedService.release()
  onBarChanged: bindService()
  onRelayUrlChanged: Qt.callLater(configure)
  onShareRegionChanged: Qt.callLater(configure)
  onSoundEnabledChanged: Qt.callLater(configure)
  // Services are created before widgets on a normal reload; the retry covers
  // a service that is still loading when the widget appears.
  Timer {
    interval: 500
    repeat: true
    running: root.service === null && root.serviceTries < root.serviceTryLimit
    onTriggered: { root.serviceTries++; root.bindService() }
  }
  Connections {
    target: root.service
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
    dimmed: !root.svc.canWave
    active: !!root.svc.baton
    tooltipText: Model.tooltipText({
      connected: root.svc.connected,
      stale: root.stale,
      identityError: root.svc.identityError,
      unreachable: root.svc.unreachable,
      pending: root.svc.pending,
      baton: root.svc.baton,
      nowMs: root.svc.nowMs,
      cooldownRemaining: root.svc.cooldownRemaining,
      nobodyAround: root.svc.nobodyAround,
      outdated: root.svc.outdated,
      lastOrigin: root.svc.lastOrigin,
      globalTotal: root.svc.globalTotal,
      online: root.svc.online,
      showCounter: root.showCounter,
      countryNames: Countries.NAMES
    }) + "\nRight-click: options · Middle-click: explore batons"

    onPressed: function(b) {
      if (b === Qt.RightButton) root.optionsOpen = !root.optionsOpen
      else if (b === Qt.MiddleButton) Util.execArgv(["xdg-open", Model.batonUrl(root.relayUrl, root.svc.baton || null)])
      else if (b === Qt.LeftButton && root.service) root.service.sendWave()
    }
  }

  PopupCard {
    id: optionsPopup
    anchorItem: button
    bar: root.bar
    owner: root
    open: root.optionsOpen
    contentWidth: optionsPopup.fittedContentWidth(Style.space(370))
    contentHeight: optionsPopup.fittedContentHeight(optionsColumn.implicitHeight)

    Column {
      id: optionsColumn
      width: parent.width
      spacing: Style.space(10)

      Text {
        text: "Your corner of Baton"
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }

      Text {
        width: parent.width
        text: "Small hellos, moving between Omarchs around the world."
        color: root.foreground
        opacity: 0.72
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        wrapMode: Text.WordWrap
      }

      Row {
        width: parent.width
        spacing: Style.space(8)

        Repeater {
          model: [
            { value: Model.formatCount(root.svc.globalTotal || 0), label: "waves sent\nto Omarchs" },
            { value: Model.formatCount(root.svc.receivedCountryCount || 0), label: "countries\nreached you" }
          ]
          Rectangle {
            required property var modelData
            width: (optionsColumn.width - Style.space(8)) / 2
            height: Style.space(88)
            radius: Style.space(8)
            color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08)
            border.color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.28)
            border.width: 1
            Column {
              anchors.centerIn: parent
              spacing: Style.space(3)
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: modelData.value
                color: root.accent
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Math.round(Style.font.subtitle * 1.5)
                font.bold: true
              }
              Text {
                anchors.horizontalCenter: parent.horizontalCenter
                horizontalAlignment: Text.AlignHCenter
                text: modelData.label
                color: root.foreground
                opacity: 0.72
                font.family: root.bar ? root.bar.fontFamily : Style.font.family
                font.pixelSize: Style.font.caption
              }
            }
          }
        }
      }

      Row {
        spacing: Style.space(7)
        Rectangle {
          width: Style.space(7); height: width; radius: width / 2
          anchors.verticalCenter: parent.verticalCenter
          color: root.svc.connected ? root.accent : root.foreground
          opacity: root.svc.connected ? 1 : 0.45
        }
        Text {
          text: root.svc.online > 0 ? Model.formatCount(root.svc.online) + " Omarchs online now" : "Waiting for the community"
          color: root.foreground
          opacity: 0.78
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.caption
        }
      }

      Rectangle { width: parent.width; height: 1; color: root.foreground; opacity: 0.12 }

      Text {
        text: "Your signal"
        color: root.foreground
        font.family: root.bar ? root.bar.fontFamily : Style.font.family
        font.pixelSize: Style.font.caption
        font.bold: true
      }

      Toggle {
        width: parent.width
        label: "Show my country"
        description: root.shareRegion ? "Waves can show your approximate country." : "Waves arrive as “somewhere”."
        checked: root.shareRegion
        foreground: root.foreground
        accent: root.accent
        onClicked: root.setSetting("shareRegion", !root.shareRegion)
      }

      Toggle {
        width: parent.width
        label: "Chime on incoming wave"
        description: root.soundEnabled ? "A short sound plays when someone waves at you." : "Waves arrive silently, with only the pulse in the bar."
        checked: root.soundEnabled
        foreground: root.foreground
        accent: root.accent
        onClicked: root.setSetting("sound", !root.soundEnabled)
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
