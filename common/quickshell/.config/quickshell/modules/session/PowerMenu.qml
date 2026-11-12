import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components
import qs.services

// Full-screen power menu. Destructive actions (reboot / shut down / log out)
// need a second press so a stray click can't end the session.
OverlayWindow {
    id: win

    name: "session"
    open: Panels.session
    dim: 0.55
    onDismissed: Panels.session = false

    property int current: 0
    property int armed: -1
    readonly property var actions: [
        {
            icon: "lock",
            label: "Lock",
            key: "L",
            confirm: false,
            run: () => Session.lock()
        },
        {
            icon: "bedtime",
            label: "Suspend",
            key: "S",
            confirm: false,
            run: () => Session.suspend()
        },
        {
            icon: "logout",
            label: "Log out",
            key: "E",
            confirm: true,
            run: () => Session.logout()
        },
        {
            icon: "restart_alt",
            label: "Reboot",
            key: "R",
            confirm: true,
            run: () => Session.reboot()
        },
        {
            icon: "power_settings_new",
            label: "Shut down",
            key: "P",
            confirm: true,
            run: () => Session.poweroff()
        }
    ]

    function trigger(i) {
        const a = actions[i];
        if (a.confirm && armed !== i) {
            armed = i;
            current = i;
            disarm.restart();
            return;
        }
        Panels.session = false;
        a.run();
    }

    Timer {
        id: disarm
        interval: 3000
        onTriggered: win.armed = -1
    }

    onOpenChanged: {
        armed = -1;
        current = 0;
    }

    onKeyPressed: e => {
        if (e.key === Qt.Key_Left)
            current = (current + actions.length - 1) % actions.length;
        else if (e.key === Qt.Key_Right)
            current = (current + 1) % actions.length;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
            trigger(current);
        else {
            const i = actions.findIndex(a => a.key === e.text.toUpperCase());
            if (i < 0)
                return;
            trigger(i);
        }
        e.accepted = true;
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 28
        opacity: win.progress
        scale: 0.94 + 0.06 * win.progress

        ColumnLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Goodbye for now, " + Session.user
                font.pixelSize: 26
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "Up " + Stats.fmtUptime()
                color: Theme.textMuted
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14

            Repeater {
                model: win.actions

                Rectangle {
                    id: btn
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.current
                    readonly property bool isArmed: index === win.armed

                    Layout.preferredWidth: 128
                    Layout.preferredHeight: 128
                    radius: Theme.radius + 8
                    color: isArmed ? Theme.red : sel ? Theme.accent : Theme.panel
                    border.width: 1
                    border.color: sel || isArmed ? "transparent" : Theme.panelBorder
                    scale: mouse.pressed ? 0.96 : 1
                    Behavior on color {
                        CAnim {
                            duration: Theme.animFast
                        }
                    }
                    Behavior on scale {
                        Anim {
                            duration: Theme.animFast
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10
                        MIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: btn.modelData.icon
                            size: 36
                            fill: btn.sel ? 1 : 0
                            color: btn.sel || btn.isArmed ? Theme.onAccent : Theme.text
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: btn.isArmed ? "Press again" : btn.modelData.label
                            font.weight: Font.DemiBold
                            color: btn.sel || btn.isArmed ? Theme.onAccent : Theme.text
                        }
                    }
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 10
                        width: 20
                        height: 20
                        radius: 6
                        color: btn.sel || btn.isArmed ? Theme.alpha(Theme.crust, 0.15) : Theme.surface0
                        StyledText {
                            anchors.centerIn: parent
                            text: btn.modelData.key
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.Bold
                            color: btn.sel || btn.isArmed ? Theme.onAccent : Theme.textMuted
                        }
                    }

                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.current = btn.index
                        onClicked: win.trigger(btn.index)
                    }
                }
            }
        }
    }
}
