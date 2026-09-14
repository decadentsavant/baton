import QtQuick
import qs.Commons
import qs.Ui
import "Model.js" as Model
import "Countries.js" as Countries

Column {
  id: root
  required property var state
  property color foreground: Color.foreground
  property color accent: Color.accent
  property string fontFamily: Style.font.family
  property bool shareRegion: true
  property bool soundEnabled: true
  property bool showCounter: true
  property bool settingsOpen: false
  readonly property var story: Model.cardState(state)
  signal wave()
  signal explore()
  signal invite()
  signal settingChanged(string key, bool value)
  spacing: Style.space(12)

  component Label: Text {
    width: parent.width
    textFormat: Text.PlainText
    color: root.foreground
    font.family: root.fontFamily
    font.pixelSize: Style.font.caption
    wrapMode: Text.WordWrap
  }

  Row {
    width: parent.width
    Text {
      width: parent.width / 3
      text: "BATON"
      color: root.accent
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
      font.bold: true
      font.letterSpacing: 2
    }
    Text {
      width: parent.width * 2 / 3
      horizontalAlignment: Text.AlignRight
      text: root.state.stale || root.state.identityError ? "Needs attention"
        : !root.state.connected ? "Reconnecting" : !root.state.statsKnown ? "Connected"
        : Model.formatCount(root.state.online) + " online"
      color: root.foreground
      opacity: 0.65
      font.family: root.fontFamily
      font.pixelSize: Style.font.caption
    }
  }

  Rectangle {
    width: parent.width
    implicitHeight: hero.implicitHeight + Style.space(28)
    radius: Style.cornerRadius
    color: Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.08)
    Column {
      id: hero
      x: Style.space(14); y: Style.space(14)
      width: parent.width - Style.space(28)
      spacing: Style.space(8)
      Text {
        text: root.story.key === "delivered" ? "✓" : root.state.baton ? "↗" : "\uDB86\uDC21"
        color: root.accent
        font.family: root.fontFamily
        font.pixelSize: Style.font.subtitle * 2
        rotation: root.story.key === "received" ? -12 : 0
        Behavior on rotation { NumberAnimation { duration: 220; easing.type: Easing.OutBack } }
      }
      Label {
        text: root.story.title
        font.pixelSize: Style.font.subtitle
        font.bold: true
      }
      Label { text: root.story.body; opacity: 0.8 }
      Button {
        width: parent.width
        text: Model.cardAction(root.state)
        fontFamily: root.fontFamily
        fontSize: Style.font.caption
        foreground: root.foreground
        accent: root.accent
        selected: enabled
        bordered: true
        focusable: true
        enabled: !!root.state.canWave && !root.state.stale
        opacity: enabled ? 1 : 0.6
        onClicked: root.wave()
      }
    }
  }

  Column {
    width: parent.width
    visible: !!root.state.baton
    spacing: Style.space(4)
    Label { text: "IN YOUR HANDS"; color: root.accent; font.bold: true }
    Label { text: Model.batonLabel(root.state.baton, root.state.nowMs); opacity: 0.8 }
  }

  Label {
    visible: !!root.state.lastOrigin && root.story.key !== "received"
    text: "Last hello · " + (Model.flagFor(root.state.lastOrigin) ? Model.flagFor(root.state.lastOrigin) + " " : "")
      + Model.originLabel(root.state.lastOrigin, Countries.NAMES)
    opacity: 0.75
  }

  Row {
    width: parent.width
    spacing: Style.space(16)
    Repeater {
      model: [
        { value: root.state.statsKnown ? Model.formatCount(root.state.globalTotal) : "—", label: root.state.connected ? "hellos worldwide" : "hellos at last connection", shown: root.showCounter },
        { value: Model.formatCount(root.state.receivedCountryCount), label: root.state.receivedCountryCount === 1 ? "country reached you" : "countries reached you", shown: true }
      ]
      Column {
        required property var modelData
        visible: modelData.shown
        width: root.showCounter ? (root.width - Style.space(16)) / 2 : root.width
        spacing: Style.space(3)
        Label { text: modelData.value; font.pixelSize: Style.font.subtitle; font.bold: true }
        Label { text: modelData.label; opacity: 0.6 }
      }
    }
  }

  Label {
    visible: !!root.state.outdated || !!root.state.stale
    text: root.state.stale ? Model.RESTART_COMMAND : "Update available · " + Model.UPDATE_COMMAND
    opacity: 0.8
    wrapMode: Text.WrapAnywhere
  }

  Rectangle { width: parent.width; height: 1; color: root.foreground; opacity: 0.12 }
  Row {
    width: parent.width
    spacing: Style.space(4)
    Button {
      width: (parent.width - parent.spacing * 2) / 3
      text: "Explore ↗"
      fontSize: Style.font.caption
      horizontalPadding: 0
      foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
      focusable: true
      onClicked: root.explore()
    }
    Button {
      width: (parent.width - parent.spacing * 2) / 3
      text: "Invite"
      fontSize: Style.font.caption
      horizontalPadding: 0
      foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
      focusable: true
      onClicked: root.invite()
    }
    Button {
      width: (parent.width - parent.spacing * 2) / 3
      text: root.settingsOpen ? "Settings −" : "Settings +"
      fontSize: Style.font.caption
      horizontalPadding: 0
      foreground: root.foreground; accent: root.accent; fontFamily: root.fontFamily
      focusable: true
      onClicked: root.settingsOpen = !root.settingsOpen
    }
  }
  Column {
    width: parent.width
    visible: root.settingsOpen
    spacing: Style.space(4)
    Toggle {
      width: parent.width
      label: "Share my country"
      description: root.shareRegion ? "Country only, estimated from your IP." : "Your hellos arrive from “somewhere”."
      titleSize: Style.font.caption
      fontFamily: root.fontFamily
      checked: root.shareRegion
      foreground: root.foreground; accent: root.accent
      onClicked: root.settingChanged("shareRegion", !root.shareRegion)
    }
    Toggle {
      width: parent.width
      label: "Incoming chime"
      titleSize: Style.font.caption
      fontFamily: root.fontFamily
      checked: root.soundEnabled
      foreground: root.foreground; accent: root.accent
      onClicked: root.settingChanged("sound", !root.soundEnabled)
    }
    Label { text: "Country count stays on this device. No names or messages."; opacity: 0.6 }
  }
}
