import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import qs.core
import qs.components
import qs.services

// Bluetooth: adapter switch, your devices (click = connect / disconnect) and,
// while the popup is open, a scan for new ones (click = pair + connect).
// Opened from the › on the control center's Bluetooth tile.
OverlayWindow {
    id: win

    name: "bluetooth"
    open: Panels.bluetooth
    dim: 0
    onDismissed: Panels.bluetooth = false

    readonly property var adapter: Net.adapter
    readonly property var devices: adapter?.devices.values ?? []
    // paired first: connected on top, then by name
    readonly property var paired: devices.filter(d => d.paired || d.bonded).sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))
    // new devices: skip nameless ones (their "name" is just the address)
    readonly property var nearby: devices.filter(d => !d.paired && !d.bonded && d.name && d.name.replace(/-/g, ":") !== d.address)

    // scan only while the popup is open
    onOpenChanged: {
        if (adapter && adapter.enabled)
            adapter.discovering = open;
    }

    function glyph(icon) {
        const i = icon || "";
        if (i.includes("headset") || i.includes("headphone"))
            return "headphones";
        if (i.includes("audio") || i.includes("speaker"))
            return "speaker";
        if (i.includes("gaming") || i.includes("joystick"))
            return "sports_esports";
        if (i.includes("mouse"))
            return "mouse";
        if (i.includes("keyboard"))
            return "keyboard";
        if (i.includes("phone"))
            return "smartphone";
        if (i.includes("computer"))
            return "computer";
        if (i.includes("watch"))
            return "watch";
        return "bluetooth";
    }
    function status(d) {
        if (d.pairing)
            return "Pairing…";
        if (d.state === BluetoothDeviceState.Connecting)
            return "Connecting…";
        if (d.state === BluetoothDeviceState.Disconnecting)
            return "Disconnecting…";
        if (d.connected)
            return "Connected" + (d.batteryAvailable ? " · " + Math.round(d.battery * 100) + "%" : "");
        return d.paired || d.bonded ? "Paired" : "Tap to pair";
    }
    function activate(d) {
        if (d.pairing || d.state === BluetoothDeviceState.Connecting || d.state === BluetoothDeviceState.Disconnecting)
            return;
        if (!d.paired && !d.bonded) {
            d.trusted = true;       // reconnect automatically next time
            d.pair();               // connects once paired (see onPairedChanged in the row)
        } else if (d.connected) {
            d.disconnect();
        } else {
            d.connect();
        }
    }

    Surface {
        id: card
        width: 440
        height: Math.min(col.implicitHeight + 28, win.height - Theme.barHeight - Theme.gap * 3)
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        y: Theme.barHeight + Theme.gap * 2 - (1 - win.progress) * 16
        opacity: win.progress

        MouseArea {
            anchors.fill: parent
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 14
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 12

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    IconButton {
                        icon: "arrow_back"
                        iconSize: 18
                        onClicked: Panels.toggle("controlCenter")
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Bluetooth"
                        font.pixelSize: Theme.fontLg
                        font.weight: Font.DemiBold
                    }
                    ToggleSwitch {
                        checked: Net.btEnabled
                        onToggled: {
                            Net.toggleBluetooth();
                            if (win.adapter && !Net.btEnabled)
                                scanStart.restart();
                        }
                    }
                }

                // adapter on → start scanning once it's powered
                Timer {
                    id: scanStart
                    interval: 800
                    onTriggered: if (win.open && win.adapter?.enabled)
                        win.adapter.discovering = true
                }

                StyledText {
                    visible: !Net.btEnabled
                    Layout.fillWidth: true
                    Layout.leftMargin: 4
                    text: "Bluetooth is off."
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                }

                // ── your devices ────────────────────────────────────
                Card {
                    visible: Net.btEnabled
                    padding: 8
                    StyledText {
                        Layout.leftMargin: 6
                        text: "MY DEVICES"
                        font.pixelSize: Theme.fontXs
                        font.weight: Font.DemiBold
                        color: Theme.textFaint
                    }
                    StyledText {
                        visible: win.paired.length === 0
                        Layout.leftMargin: 6
                        text: "No paired devices yet"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm
                    }
                    Repeater {
                        model: win.paired
                        DeviceItem {}
                    }
                }

                // ── nearby ──────────────────────────────────────────
                Card {
                    visible: Net.btEnabled
                    padding: 8
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 6
                        StyledText {
                            Layout.fillWidth: true
                            text: "NEARBY"
                            font.pixelSize: Theme.fontXs
                            font.weight: Font.DemiBold
                            color: Theme.textFaint
                        }
                        MIcon {
                            visible: win.adapter?.discovering ?? false
                            icon: "progress_activity"
                            size: 16
                            color: Theme.accent
                            RotationAnimator on rotation {
                                running: win.open && (win.adapter?.discovering ?? false)
                                from: 0
                                to: 360
                                duration: 1100
                                loops: Animation.Infinite
                            }
                        }
                        IconButton {
                            implicitWidth: 28
                            implicitHeight: 28
                            icon: "refresh"
                            iconSize: 16
                            onClicked: {
                                if (!win.adapter)
                                    return;
                                win.adapter.discovering = false;
                                scanStart.restart();
                            }
                        }
                    }
                    StyledText {
                        visible: win.nearby.length === 0
                        Layout.leftMargin: 6
                        text: (win.adapter?.discovering ?? false) ? "Searching… put your device in pairing mode" : "Nothing found"
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm
                    }
                    Repeater {
                        model: win.nearby
                        DeviceItem {}
                    }
                }
            }
        }
    }

    // one device row: icon · name / status · forget (paired only)
    component DeviceItem: Rectangle {
        id: item
        required property var modelData
        readonly property var dev: modelData
        readonly property bool busy: dev.pairing || dev.state === BluetoothDeviceState.Connecting || dev.state === BluetoothDeviceState.Disconnecting
        Layout.fillWidth: true
        implicitHeight: 46
        radius: Theme.radiusSm
        color: rowMouse.containsMouse ? Theme.hover : "transparent"

        // freshly paired → connect right away
        Connections {
            target: item.dev
            function onPairedChanged() {
                if (item.dev.paired && !item.dev.connected)
                    item.dev.connect();
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: item.busy ? Qt.BusyCursor : Qt.PointingHandCursor
            onClicked: win.activate(item.dev)
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 4
            spacing: 12
            Rectangle {
                Layout.preferredWidth: 30
                Layout.preferredHeight: 30
                radius: 15
                color: item.dev.connected ? Theme.accent : Theme.surface0
                MIcon {
                    anchors.centerIn: parent
                    icon: win.glyph(item.dev.icon)
                    size: 17
                    fill: item.dev.connected ? 1 : 0
                    color: item.dev.connected ? Theme.onAccent : Theme.text
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0
                StyledText {
                    Layout.fillWidth: true
                    text: item.dev.name || item.dev.address
                    font.pixelSize: Theme.fontSm
                    font.weight: item.dev.connected ? Font.DemiBold : Font.Normal
                }
                StyledText {
                    Layout.fillWidth: true
                    text: win.status(item.dev)
                    font.pixelSize: Theme.fontXs
                    color: item.dev.connected ? Theme.accent : Theme.textMuted
                }
            }
            IconButton {
                visible: (item.dev.paired || item.dev.bonded) && rowMouse.containsMouse || forgetBtn.hovered
                id: forgetBtn
                implicitWidth: 30
                implicitHeight: 30
                icon: "delete"
                iconSize: 16
                danger: true
                onClicked: item.dev.forget()
            }
        }
    }
}
