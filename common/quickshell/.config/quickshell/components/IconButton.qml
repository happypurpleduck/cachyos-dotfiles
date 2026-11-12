import QtQuick
import qs.core

// Round/rounded icon button. `active` paints it in the accent.
Rectangle {
    id: root

    property string icon: ""
    property real iconSize: Theme.iconSize
    property bool active: false
    property bool danger: false
    property color iconColor: active ? Theme.onAccent : (danger ? Theme.red : Theme.text)
    property string tooltip: ""
    readonly property bool hovered: mouse.containsMouse

    signal clicked
    signal rightClicked

    implicitWidth: 32
    implicitHeight: 32
    radius: Theme.radiusSm
    color: active ? Theme.accent : (mouse.pressed ? Theme.press : (hovered ? Theme.hover : "transparent"))

    Behavior on color {
        CAnim {
            duration: Theme.animFast
        }
    }

    MIcon {
        anchors.centerIn: parent
        icon: root.icon
        size: root.iconSize
        color: root.iconColor
        fill: root.active || root.hovered ? 1 : 0
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }
}
