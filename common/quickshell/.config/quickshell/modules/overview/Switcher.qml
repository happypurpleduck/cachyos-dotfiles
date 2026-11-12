import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.components

// Alt-Tab window switcher. Hyprland's ALT+Tab bind calls `switcher next`
// repeatedly while Alt is held; releasing Alt focuses the selection.
OverlayWindow {
    id: win

    name: "switcher"
    open: Panels.switcher
    dim: 0.2
    duration: Theme.animFast
    onDismissed: Panels.switcher = false

    property var windows: []
    property int index: 0

    function step(delta) {
        if (!Panels.switcher) {
            windows = Hypr.windowsByFocus();
            if (windows.length === 0)
                return;
            index = windows.length > 1 ? (delta > 0 ? 1 : windows.length - 1) : 0;
            Panels.closeAll();
            Panels.switcher = true;
            return;
        }
        if (windows.length > 0)
            index = (index + delta + windows.length) % windows.length;
    }
    function commit() {
        if (!Panels.switcher)
            return;
        const w = windows[index];
        Panels.switcher = false;
        if (w)
            Hypr.focusWindow(w.address);
    }

    onOpenChanged: if (open)
        Hyprland.refreshToplevels()

    onKeyReleased: e => {
        if (e.key === Qt.Key_Alt || e.key === Qt.Key_Meta)
            commit();
    }
    onKeyPressed: e => {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) {
            commit();
            e.accepted = true;
        } else if (e.key === Qt.Key_Right) {
            step(1);
            e.accepted = true;
        } else if (e.key === Qt.Key_Left) {
            step(-1);
            e.accepted = true;
        }
    }

    Surface {
        anchors.centerIn: parent
        width: Math.min(parent.width - 120, row.implicitWidth + 32)
        height: 236
        opacity: win.progress
        scale: 0.97 + 0.03 * win.progress

        MouseArea {
            anchors.fill: parent
        }

        ListView {
            id: row
            anchors.fill: parent
            anchors.margins: 16
            orientation: ListView.Horizontal
            spacing: 10
            model: win.windows
            currentIndex: win.index
            implicitWidth: win.windows.length * 230 - 10
            highlightMoveDuration: Theme.animFast
            clip: true

            delegate: Rectangle {
                id: card
                required property var modelData
                required property int index
                readonly property bool sel: index === win.index
                readonly property var ipc: modelData.lastIpcObject

                width: 220
                height: 204
                radius: Theme.radius
                color: sel ? Theme.surface0 : "transparent"
                border.width: sel ? 2 : 0
                border.color: Theme.accent

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 10
                    spacing: 8

                    ClippingRectangle {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        radius: Theme.radiusSm
                        color: Theme.mantle
                        ScreencopyView {
                            anchors.fill: parent
                            captureSource: win.open ? card.modelData.wayland : null
                            live: false
                            constraintSize: Qt.size(width, height)
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8
                        IconImage {
                            Layout.preferredWidth: 20
                            Layout.preferredHeight: 20
                            source: Hypr.iconFor(card.ipc?.class ?? "")
                        }
                        StyledText {
                            Layout.fillWidth: true
                            text: card.modelData.title
                            font.pixelSize: Theme.fontSm
                            font.weight: card.sel ? Font.DemiBold : Font.Normal
                            color: card.sel ? Theme.text : Theme.subtext0
                        }
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    hoverEnabled: true
                    onEntered: win.index = card.index
                    onClicked: win.commit()
                }
            }
        }
    }
}
