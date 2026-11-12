import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import Quickshell.Widgets
import qs.core
import qs.components

// Workspace overview: a grid of workspaces with live window thumbnails.
// Click a window to focus it, an empty spot to switch, drag a window to move it,
// middle-click to close it.
OverlayWindow {
    id: win

    name: "overview"
    open: Panels.overview
    dim: 0.45
    onDismissed: Panels.overview = false

    readonly property var monitor: Hyprland.focusedMonitor
    readonly property real monW: (monitor?.width ?? 2560) / (monitor?.scale ?? 1)
    readonly property real monH: (monitor?.height ?? 1440) / (monitor?.scale ?? 1)
    readonly property int activeWs: monitor?.activeWorkspace?.id ?? 1
    readonly property int columns: 5
    readonly property int rows: 2
    readonly property real cellW: Math.min((width - 160) / columns - 16, 360)
    readonly property real cellH: cellW * monH / monW
    readonly property real k: cellW / monW
    property int dragTarget: -1
    property int dragSource: -1

    onOpenChanged: if (open) {
        Hyprland.refreshToplevels();
        Hyprland.refreshWorkspaces();
    }

    onKeyPressed: e => {
        const n = e.key - Qt.Key_0;
        if (n >= 1 && n <= 9) {
            Hypr.focusWorkspace(n);
            Panels.overview = false;
        } else if (e.key === Qt.Key_0) {
            Hypr.focusWorkspace(10);
            Panels.overview = false;
        }
    }

    GridLayout {
        id: grid
        anchors.centerIn: parent
        columns: win.columns
        rowSpacing: 16
        columnSpacing: 16
        opacity: win.progress
        scale: 0.96 + 0.04 * win.progress

        Repeater {
            model: win.columns * win.rows

            Rectangle {
                id: cell
                required property int index
                readonly property int wsId: index + 1
                readonly property bool isActive: wsId === win.activeWs
                readonly property var windows: Hyprland.toplevels.values.filter(t => t.workspace?.id === cell.wsId && t.lastIpcObject?.at)

                Layout.preferredWidth: win.cellW
                Layout.preferredHeight: win.cellH
                radius: Theme.radius
                color: Theme.alpha(Theme.base, 0.9)
                border.width: 2
                border.color: win.dragTarget === wsId ? Theme.accent : isActive ? Theme.accentMuted : Theme.alpha(Theme.surface1, 0.6)
                clip: win.dragSource !== wsId
                z: win.dragSource === wsId ? 10 : 0

                Image {
                    anchors.fill: parent
                    anchors.margins: 2
                    source: Theme.wallpaper ? `file://${Theme.thumbDir}/${Theme.wallpaper.split("/").pop()}.jpg` : ""
                    fillMode: Image.PreserveAspectCrop
                    opacity: 0.35
                    asynchronous: true
                }

                StyledText {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    text: cell.wsId
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.Bold
                    color: cell.isActive ? Theme.accent : Theme.overlay1
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        Hypr.focusWorkspace(cell.wsId);
                        Panels.overview = false;
                    }
                }

                DropArea {
                    anchors.fill: parent
                    onEntered: win.dragTarget = cell.wsId
                    onExited: if (win.dragTarget === cell.wsId)
                        win.dragTarget = -1
                }

                Repeater {
                    model: cell.windows

                    Item {
                        id: tile
                        required property var modelData
                        readonly property var ipc: modelData.lastIpcObject
                        readonly property real ox: (win.monitor?.x ?? 0)
                        readonly property real oy: (win.monitor?.y ?? 0)

                        x: (ipc.at[0] - ox) * win.k
                        y: (ipc.at[1] - oy) * win.k
                        width: Math.max(24, ipc.size[0] * win.k)
                        height: Math.max(18, ipc.size[1] * win.k)
                        z: ipc.floating ? 2 : 1

                        Drag.active: dragArea.drag.active
                        Drag.hotSpot.x: width / 2
                        Drag.hotSpot.y: height / 2

                        ClippingRectangle {
                            anchors.fill: parent
                            anchors.margins: 1
                            radius: Theme.radiusXs
                            color: Theme.surface0
                            border.width: dragArea.containsMouse ? 2 : 1
                            border.color: dragArea.containsMouse ? Theme.accent : Theme.surface1

                            ScreencopyView {
                                anchors.fill: parent
                                captureSource: win.open ? tile.modelData.wayland : null
                                live: false
                                constraintSize: Qt.size(width, height)
                            }
                            IconImage {
                                anchors.right: parent.right
                                anchors.bottom: parent.bottom
                                anchors.margins: 6
                                implicitSize: Math.min(22, parent.height * 0.3)
                                source: Hypr.iconFor(tile.ipc.class)
                            }
                        }

                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            hoverEnabled: true
                            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                            cursorShape: Qt.PointingHandCursor
                            drag.target: tile
                            property point start
                            onPressed: e => {
                                start = Qt.point(tile.x, tile.y);
                                win.dragSource = cell.wsId;
                            }
                            onReleased: e => {
                                win.dragSource = -1;
                                const moved = Math.abs(tile.x - start.x) + Math.abs(tile.y - start.y) > 6;
                                if (!moved)
                                    return;
                                const target = win.dragTarget;
                                tile.x = Qt.binding(() => (tile.ipc.at[0] - tile.ox) * win.k);
                                tile.y = Qt.binding(() => (tile.ipc.at[1] - tile.oy) * win.k);
                                win.dragTarget = -1;
                                if (target > 0 && target !== cell.wsId)
                                    Hypr.moveWindowToWorkspace(tile.ipc.address, target);
                                Qt.callLater(Hyprland.refreshToplevels);
                            }
                            onClicked: e => {
                                if (e.button === Qt.MiddleButton) {
                                    Hypr.closeWindow(tile.ipc.address);
                                    Qt.callLater(Hyprland.refreshToplevels);
                                    return;
                                }
                                Hypr.focusWindow(tile.ipc.address);
                                Panels.overview = false;
                            }
                        }
                    }
                }
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: grid.bottom
        anchors.topMargin: 24
        opacity: win.progress * 0.8
        text: "Click to focus  ·  drag to move  ·  middle-click to close  ·  1–0 to jump"
        color: Theme.subtext0
        font.pixelSize: Theme.fontSm
    }
}
