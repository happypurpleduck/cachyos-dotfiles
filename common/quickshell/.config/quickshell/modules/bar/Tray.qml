import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.core
import qs.components

// System tray icons; left click = activate, right click = menu.
RowLayout {
    id: root

    required property var barWindow
    visible: SystemTray.items.values.length > 0
    spacing: 2

    Repeater {
        model: SystemTray.items

        Rectangle {
            id: item
            required property SystemTrayItem modelData
            Layout.preferredWidth: 28
            Layout.preferredHeight: 28
            radius: Theme.radiusSm
            color: mouse.containsMouse ? Theme.hover : "transparent"

            IconImage {
                anchors.centerIn: parent
                implicitSize: 16
                source: {
                    const i = item.modelData.icon;
                    // some apps hand us "name?path=/dir"; resolve via the given path
                    if (i.includes("?path=")) {
                        const [name, path] = i.split("?path=");
                        return `file://${path}/${name.slice(name.lastIndexOf("/") + 1)}`;
                    }
                    return i;
                }
            }

            QsMenuAnchor {
                id: menu
                menu: item.modelData.menu
                anchor.window: root.barWindow
                anchor.item: item
                anchor.edges: Edges.Bottom
                anchor.gravity: Edges.Bottom
                anchor.margins.top: 10
            }

            MouseArea {
                id: mouse
                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: e => {
                    if (e.button === Qt.RightButton || item.modelData.onlyMenu) {
                        if (item.modelData.hasMenu)
                            menu.open();
                    } else if (e.button === Qt.MiddleButton) {
                        item.modelData.secondaryActivate();
                    } else {
                        item.modelData.activate();
                    }
                }
            }
        }
    }

    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        Layout.leftMargin: 4
        Layout.rightMargin: 2
        color: Theme.surface1
    }
}
