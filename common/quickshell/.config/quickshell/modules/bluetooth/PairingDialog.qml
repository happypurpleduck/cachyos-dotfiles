import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components
import qs.services

// Bluetooth pairing prompt, driven by the shell's BlueZ agent (services/BtAgent).
//   confirm   — "does this code match the one on the device?"
//   authorize — "allow this device to pair?"
//   pin       — type a PIN (often 0000 / 1234)
//   passkey   — type the 6-digit number shown on the device
//   display   — type this code on the device (keyboards); closes once paired
OverlayWindow {
    id: win

    readonly property var req: BtAgent.request
    readonly property string kind: req?.type ?? ""
    readonly property bool needsInput: kind === "pin" || kind === "passkey"

    name: "btpair"
    open: req !== null
    dim: 0.5
    onDismissed: BtAgent.dismiss()
    onReqChanged: if (req) {
        field.text = "";
        if (needsInput)
            field.forceActiveFocus();
    }

    // "display": close when the device reports it's paired
    readonly property var device: req?.path ? (Net.adapter?.devices.values ?? []).find(d => d.dbusPath === req.path) ?? null : null
    Connections {
        target: win.device
        enabled: win.kind === "display"
        function onPairedChanged() {
            if (win.device.paired)
                BtAgent.next();
        }
    }

    // "123456" → "123 456"
    function spaced(code) {
        const c = String(code ?? "");
        return c.length === 6 ? c.slice(0, 3) + " " + c.slice(3) : c;
    }
    function accept() {
        if (needsInput) {
            if (field.text.length === 0)
                return;
            BtAgent.respond(true, field.text);
        } else {
            BtAgent.respond(true);
        }
    }

    Surface {
        width: 420
        height: col.implicitHeight + 48
        anchors.centerIn: parent
        opacity: win.progress
        scale: 0.95 + 0.05 * win.progress

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 24
            spacing: 14

            Rectangle {
                Layout.preferredWidth: 48
                Layout.preferredHeight: 48
                radius: Theme.radius
                color: Theme.accentSoft
                MIcon {
                    anchors.centerIn: parent
                    icon: "bluetooth_searching"
                    size: 26
                    fill: 1
                    color: Theme.accent
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: win.kind === "authorize" ? "Allow pairing?" : "Pair with " + (win.req?.device ?? "")
                font.pixelSize: Theme.fontXl
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                elide: Text.ElideNone
                color: Theme.textMuted
                text: {
                    switch (win.kind) {
                    case "confirm":
                        return "Make sure this code is shown on " + win.req.device + ", then confirm.";
                    case "authorize":
                        return win.req.device + " wants to pair with this computer.";
                    case "pin":
                        return "Enter the PIN for " + win.req.device + ". Many devices use 0000 or 1234.";
                    case "passkey":
                        return "Enter the 6-digit code shown on " + win.req.device + ".";
                    case "display":
                        return "Type this code on " + win.req.device + ", then press Enter on it.";
                    }
                    return "";
                }
            }

            // code to compare / type on the device
            Rectangle {
                visible: win.kind === "confirm" || win.kind === "display"
                Layout.fillWidth: true
                Layout.preferredHeight: 72
                radius: Theme.radiusSm
                color: Theme.mantle
                Row {
                    anchors.centerIn: parent
                    spacing: 2
                    Repeater {
                        model: win.spaced(win.kind === "confirm" ? win.req?.passkey : win.req?.code).split("")
                        StyledText {
                            required property string modelData
                            required property int index
                            // on "display", digits already typed on the device dim out
                            readonly property int digit: index > 3 ? index - 1 : index
                            text: modelData
                            font.family: Theme.fontMono
                            font.pixelSize: 34
                            font.weight: Font.DemiBold
                            color: win.kind === "display" && modelData !== " " && digit < (win.req?.entered ?? 0) ? Theme.overlay0 : Theme.accent
                        }
                    }
                }
            }

            // PIN / passkey entry
            Rectangle {
                visible: win.needsInput
                Layout.fillWidth: true
                Layout.preferredHeight: 46
                radius: Theme.radiusSm
                color: Theme.mantle
                border.width: 2
                border.color: field.activeFocus ? Theme.accent : Theme.surface1

                TextInput {
                    id: field
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    anchors.rightMargin: 14
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.text
                    font.family: Theme.fontMono
                    font.pixelSize: Theme.fontLg
                    font.letterSpacing: 2
                    maximumLength: win.kind === "passkey" ? 6 : 16
                    inputMethodHints: win.kind === "passkey" ? Qt.ImhDigitsOnly : Qt.ImhNone
                    validator: RegularExpressionValidator {
                        regularExpression: win.kind === "passkey" ? /[0-9]{0,6}/ : /\S{0,16}/
                    }
                    clip: true
                    onAccepted: win.accept()
                    Keys.onEscapePressed: BtAgent.dismiss()
                }
                StyledText {
                    anchors.fill: parent
                    anchors.leftMargin: 14
                    visible: field.text.length === 0
                    text: win.kind === "passkey" ? "6-digit code" : "PIN"
                    color: Theme.overlay0
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 4
                spacing: 8
                Item {
                    Layout.fillWidth: true
                }
                DialogButton {
                    text: win.kind === "display" ? "Close" : win.kind === "authorize" ? "Deny" : "Cancel"
                    onClicked: BtAgent.dismiss()
                }
                DialogButton {
                    visible: win.kind !== "display"
                    primary: true
                    text: win.kind === "confirm" ? "Codes match" : win.kind === "authorize" ? "Allow" : "Pair"
                    onClicked: win.accept()
                }
            }
        }
    }

    // Enter = confirm for the button-only prompts too
    onKeyPressed: e => {
        if (!needsInput && (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && kind !== "display") {
            accept();
            e.accepted = true;
        }
    }
}
