import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

// Capture palette: screenshots, recordings, colour picker.
OverlayWindow {
    id: win

    name: "capture"
    open: Panels.capture
    dim: 0.2
    onDismissed: Panels.capture = false

    property int current: 0
    readonly property var items: [
        {
            icon: "screenshot_region",
            label: "Select",
            group: "Screenshot",
            run: () => Capture.region()
        },
        {
            icon: "select_window",
            label: "Window",
            group: "Screenshot",
            run: () => Capture.window()
        },
        {
            icon: "screenshot_monitor",
            label: "Screen",
            group: "Screenshot",
            run: () => Capture.screen()
        },
        {
            icon: "screen_record",
            label: Recorder.recording ? "Stop" : "Record region",
            group: "Record",
            run: () => {
                Panels.closeAll();
                Recorder.recording ? Recorder.stop() : Recorder.start("region", true);
            }
        },
        {
            icon: "videocam",
            label: Recorder.recording ? "Stop" : "Record screen",
            group: "Record",
            run: () => {
                Panels.closeAll();
                Recorder.recording ? Recorder.stop() : Recorder.start("screen", true);
            }
        },
        {
            icon: "colorize",
            label: "Pick colour",
            group: "Tools",
            run: () => Capture.pickColor()
        }
    ]

    onOpenChanged: if (open)
        current = 0

    onKeyPressed: e => {
        if (e.key === Qt.Key_Left)
            current = (current + items.length - 1) % items.length;
        else if (e.key === Qt.Key_Right)
            current = (current + 1) % items.length;
        else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
            items[current].run();
        else
            return;
        e.accepted = true;
    }

    Surface {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 80 - (1 - win.progress) * 30
        opacity: win.progress
        width: row.implicitWidth + 24
        height: 112

        MouseArea {
            anchors.fill: parent
        }

        RowLayout {
            id: row
            anchors.centerIn: parent
            spacing: 6

            Repeater {
                model: win.items

                Rectangle {
                    id: tile
                    required property var modelData
                    required property int index
                    readonly property bool sel: index === win.current
                    Layout.preferredWidth: 96
                    Layout.preferredHeight: 88
                    Layout.leftMargin: index === 3 || index === 5 ? 10 : 0
                    radius: Theme.radius
                    color: sel ? Theme.accent : (mouse.containsMouse ? Theme.surface1 : Theme.surface0)
                    Behavior on color {
                        CAnim {
                            duration: Theme.animFast
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        MIcon {
                            Layout.alignment: Qt.AlignHCenter
                            icon: tile.modelData.icon
                            size: 26
                            fill: tile.sel ? 1 : 0
                            color: tile.sel ? Theme.onAccent : Theme.text
                        }
                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: tile.modelData.label
                            font.pixelSize: Theme.fontSm
                            font.weight: Font.Medium
                            color: tile.sel ? Theme.onAccent : Theme.subtext1
                        }
                    }
                    MouseArea {
                        id: mouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: win.current = tile.index
                        onClicked: tile.modelData.run()
                    }
                }
            }
        }
    }
}
