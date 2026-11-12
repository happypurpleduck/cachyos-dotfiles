import QtQuick
import qs.core
import qs.components

// Accent dot that opens the launcher. Doubles as the "current accent" indicator.
Rectangle {
    id: root

    implicitWidth: 28
    implicitHeight: 28
    radius: Theme.radiusSm
    color: mouse.containsMouse ? Theme.accentMuted : Theme.accentSoft
    Behavior on color {
        CAnim {
            duration: Theme.animFast
        }
    }

    MIcon {
        anchors.centerIn: parent
        icon: "search"
        size: 17
        weight: 600
        color: Theme.accent
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? Panels.openLauncher("@") : Panels.openLauncher("")
    }
}
