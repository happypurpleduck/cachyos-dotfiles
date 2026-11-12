import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components

// Visuals shared by the lock screen and the login greeter.
// The owner wires `submitted(password)` to PAM / greetd and sets busy/message.
Item {
    id: root

    property string user: ""
    property string facePath: ""
    property string wallpaper: Theme.wallpaper
    property bool busy: false
    property string message: ""
    property bool messageIsError: false
    property bool showPower: true
    property bool showMedia: false
    property real reveal: 1           // 0→1 entrance animation driven by the owner
    property string keyboardLayout: "" // short layout name ("EN", "AR"); hidden when empty
    property alias password: field.text

    signal submitted(string password)
    signal powerAction(string action)  // "suspend" | "reboot" | "poweroff"
    signal layoutClicked

    function shake() {
        shakeAnim.restart();
    }
    function clear() {
        field.text = "";
    }
    function focusField() {
        field.forceActiveFocus();
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.crust
    }

    // blurred, dimmed wallpaper
    Image {
        id: wall
        anchors.fill: parent
        source: root.wallpaper ? "file://" + root.wallpaper : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
        sourceSize.width: 1920
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        visible: wall.status === Image.Ready
        blurEnabled: true
        blur: 1
        blurMax: 64
        autoPaddingEnabled: false
        brightness: -0.32
        saturation: -0.1
        scale: 1.06 - 0.06 * root.reveal
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Theme.alpha(Theme.crust, 0.15)
            }
            GradientStop {
                position: 1
                color: Theme.alpha(Theme.crust, 0.65)
            }
        }
    }

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // clock
    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.16 + (1 - root.reveal) * -30
        opacity: root.reveal
        spacing: 0

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "HH:mm")
            font.pixelSize: 128
            font.weight: Font.Light
            font.features: ({
                    "tnum": 1
                })
            color: Theme.text
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: Qt.formatDateTime(clock.date, "dddd, d MMMM")
            font.pixelSize: 22
            color: Theme.subtext1
        }
    }

    // user + password
    ColumnLayout {
        id: authBox
        anchors.horizontalCenter: parent.horizontalCenter
        y: parent.height * 0.56 + (1 - root.reveal) * 30
        opacity: root.reveal
        spacing: 16

        ClippingRectangle {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 88
            Layout.preferredHeight: 88
            radius: 44
            color: Theme.accent
            border.width: 3
            border.color: Theme.accent
            Image {
                id: face
                anchors.fill: parent
                anchors.margins: 3
                source: root.facePath ? "file://" + root.facePath : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 176
            }
            StyledText {
                anchors.centerIn: parent
                visible: face.status !== Image.Ready
                text: root.user.charAt(0).toUpperCase()
                color: Theme.onAccent
                font.pixelSize: 36
                font.weight: Font.Bold
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: root.user
            font.pixelSize: Theme.fontXl
            font.weight: Font.DemiBold
        }

        Rectangle {
            id: pill
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 340
            Layout.preferredHeight: 52
            radius: 26
            color: Theme.alpha(Theme.base, 0.85)
            border.width: 2
            border.color: root.messageIsError ? Theme.red : field.activeFocus ? Theme.accent : Theme.surface1
            Behavior on border.color {
                CAnim {}
            }

            transform: Translate {
                id: shakeT
            }
            SequentialAnimation {
                id: shakeAnim
                loops: 1
                NumberAnimation {
                    target: shakeT
                    property: "x"
                    to: -12
                    duration: 50
                }
                NumberAnimation {
                    target: shakeT
                    property: "x"
                    to: 12
                    duration: 80
                }
                NumberAnimation {
                    target: shakeT
                    property: "x"
                    to: -8
                    duration: 70
                }
                NumberAnimation {
                    target: shakeT
                    property: "x"
                    to: 0
                    duration: 60
                }
            }

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 8
                spacing: 10

                MIcon {
                    icon: "lock"
                    size: 18
                    color: Theme.textFaint
                }

                Item {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    TextInput {
                        id: field
                        anchors.fill: parent
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        passwordCharacter: "•"
                        color: Theme.text
                        font.family: Theme.fontSans
                        font.pixelSize: 18
                        font.letterSpacing: 2
                        focus: true
                        enabled: !root.busy
                        clip: true
                        onAccepted: if (text.length > 0)
                            root.submitted(text)
                    }
                    StyledText {
                        anchors.fill: parent
                        visible: field.text.length === 0
                        text: root.busy ? "Checking…" : "Password"
                        color: Theme.overlay0
                        font.pixelSize: Theme.fontLg
                    }
                }

                // current keyboard layout; click (or Super+Space) switches
                Rectangle {
                    visible: root.keyboardLayout !== ""
                    Layout.preferredWidth: kbText.implicitWidth + 16
                    Layout.preferredHeight: 26
                    radius: 13
                    color: kbMouse.containsMouse ? Theme.surface1 : Theme.surface0
                    Behavior on color {
                        CAnim {}
                    }
                    StyledText {
                        id: kbText
                        anchors.centerIn: parent
                        text: root.keyboardLayout
                        font.family: Theme.fontMono
                        font.pixelSize: Theme.fontSm
                        font.weight: Font.DemiBold
                        color: Theme.accent
                    }
                    MouseArea {
                        id: kbMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.layoutClicked();
                            field.forceActiveFocus();
                        }
                    }
                }

                Rectangle {
                    Layout.preferredWidth: 38
                    Layout.preferredHeight: 38
                    radius: 19
                    color: field.text.length > 0 ? Theme.accent : Theme.surface0
                    Behavior on color {
                        CAnim {}
                    }
                    MIcon {
                        anchors.centerIn: parent
                        icon: root.busy ? "progress_activity" : "arrow_forward"
                        size: 20
                        weight: 600
                        color: field.text.length > 0 ? Theme.onAccent : Theme.overlay1
                        RotationAnimation on rotation {
                            running: root.busy
                            from: 0
                            to: 360
                            duration: 900
                            loops: Animation.Infinite
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (field.text.length > 0)
                            root.submitted(field.text)
                    }
                }
            }
        }

        StyledText {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: 18
            text: root.message
            color: root.messageIsError ? Theme.red : Theme.textMuted
            font.pixelSize: Theme.fontSm
        }
    }

    // bottom-right power actions
    RowLayout {
        visible: root.showPower
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 32
        opacity: root.reveal
        spacing: 8

        Repeater {
            model: [
                {
                    icon: "bedtime",
                    action: "suspend"
                },
                {
                    icon: "restart_alt",
                    action: "reboot"
                },
                {
                    icon: "power_settings_new",
                    action: "poweroff"
                }
            ]
            Rectangle {
                required property var modelData
                width: 44
                height: 44
                radius: 22
                color: m.containsMouse ? Theme.alpha(Theme.surface1, 0.9) : Theme.alpha(Theme.base, 0.7)
                MIcon {
                    anchors.centerIn: parent
                    icon: parent.modelData.icon
                    size: 20
                }
                MouseArea {
                    id: m
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.powerAction(parent.modelData.action)
                }
            }
        }
    }

    // bottom-left: keyboard layout hint / caps lock could live here; keep it calm.
    StyledText {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 36
        opacity: root.reveal * 0.7
        text: root.showMedia ? "" : Qt.formatDateTime(clock.date, "yyyy")
        visible: false
    }
}
