import QtQuick
import qs.core

// Small pill switch used in the shell's detail popups.
Rectangle {
    id: sw

    property bool checked: false
    signal toggled

    implicitWidth: 40
    implicitHeight: 22
    radius: height / 2
    color: checked ? Theme.accent : Theme.surface1
    Behavior on color {
        CAnim {}
    }

    Rectangle {
        width: 16
        height: 16
        radius: 8
        anchors.verticalCenter: parent.verticalCenter
        x: sw.checked ? parent.width - width - 3 : 3
        color: sw.checked ? Theme.onAccent : Theme.overlay2
        Behavior on x {
            Anim {
                duration: Theme.animFast
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
}
