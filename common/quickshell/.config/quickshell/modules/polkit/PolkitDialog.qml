import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Polkit
import qs.core
import qs.components

// Polkit authentication agent drawn by the shell (replaces hyprpolkitagent).
Scope {
    id: root

    PolkitAgent {
        id: agent
    }

    readonly property var flow: agent.flow
    property bool busy: false

    Connections {
        target: root.flow
        function onAuthenticationFailed() {
            root.busy = false;
            field.text = "";
            shake.restart();
            field.forceActiveFocus();
        }
        function onIsResponseRequiredChanged() {
            if (root.flow?.isResponseRequired) {
                root.busy = false;
                field.forceActiveFocus();
            }
        }
    }

    OverlayWindow {
        id: win
        name: "polkit"
        open: agent.isActive && root.flow !== null
        dim: 0.5
        onDismissed: root.flow?.cancelAuthenticationRequest()
        onOpenChanged: if (open) {
            root.busy = false;
            field.text = "";
            field.forceActiveFocus();
        }

        Surface {
            width: 420
            height: col.implicitHeight + 48
            anchors.centerIn: parent
            opacity: win.progress
            scale: 0.95 + 0.05 * win.progress

            transform: Translate {
                id: shakeT
            }
            SequentialAnimation {
                id: shake
                NumberAnimation {
                    target: shakeT
                    property: "x"
                    to: -10
                    duration: 50
                }
                NumberAnimation {
                    target: shakeT
                    property: "x"
                    to: 10
                    duration: 80
                }
                NumberAnimation {
                    target: shakeT
                    property: "x"
                    to: 0
                    duration: 60
                }
            }

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
                        icon: "admin_panel_settings"
                        size: 26
                        fill: 1
                        color: Theme.accent
                    }
                }
                StyledText {
                    text: "Authentication required"
                    font.pixelSize: Theme.fontXl
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: root.flow?.message ?? ""
                    color: Theme.textMuted
                    wrapMode: Text.Wrap
                    elide: Text.ElideNone
                }
                StyledText {
                    Layout.fillWidth: true
                    visible: (root.flow?.identities?.length ?? 0) > 0
                    text: "as " + (root.flow?.selectedIdentity?.displayName || root.flow?.selectedIdentity?.name || Quickshell.env("USER"))
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 46
                    radius: Theme.radiusSm
                    color: Theme.mantle
                    border.width: 2
                    border.color: root.flow?.supplementaryIsError ? Theme.red : field.activeFocus ? Theme.accent : Theme.surface1

                    TextInput {
                        id: field
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        anchors.rightMargin: 14
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: Theme.fontLg
                        enabled: !root.busy
                        clip: true
                        onAccepted: submit.clicked()
                        Keys.onEscapePressed: root.flow?.cancelAuthenticationRequest()
                    }
                    StyledText {
                        anchors.fill: parent
                        anchors.leftMargin: 14
                        visible: field.text.length === 0
                        text: (root.flow?.inputPrompt || "Password").replace(/:\s*$/, "")
                        color: Theme.overlay0
                    }
                }

                StyledText {
                    Layout.fillWidth: true
                    visible: text !== ""
                    text: root.flow?.supplementaryMessage ?? ""
                    color: root.flow?.supplementaryIsError ? Theme.red : Theme.textMuted
                    font.pixelSize: Theme.fontSm
                    wrapMode: Text.Wrap
                }

                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 4
                    spacing: 8
                    Item {
                        Layout.fillWidth: true
                    }
                    DialogButton {
                        text: "Cancel"
                        onClicked: root.flow?.cancelAuthenticationRequest()
                    }
                    DialogButton {
                        id: submit
                        text: root.busy ? "Checking…" : "Authenticate"
                        primary: true
                        onClicked: {
                            if (!root.flow || root.busy)
                                return;
                            root.busy = true;
                            root.flow.submit(field.text);
                        }
                    }
                }
            }
        }
    }

    component DialogButton: Rectangle {
        id: b
        property string text
        property bool primary: false
        signal clicked
        implicitWidth: label.implicitWidth + 32
        implicitHeight: 38
        radius: Theme.radiusSm
        color: primary ? (m.containsMouse ? Theme.mix(Theme.accent, Theme.text, 0.15) : Theme.accent) : (m.containsMouse ? Theme.surface1 : Theme.surface0)
        StyledText {
            id: label
            anchors.centerIn: parent
            text: b.text
            font.weight: Font.DemiBold
            color: b.primary ? Theme.onAccent : Theme.text
        }
        MouseArea {
            id: m
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
    }
}
