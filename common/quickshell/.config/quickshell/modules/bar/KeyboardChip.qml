import QtQuick
import qs.core
import qs.components
import qs.services

// Current keyboard layout (EN / AR). Click or Super+Space switches.
Rectangle {
    id: root

    implicitWidth: label.implicitWidth + 16
    implicitHeight: 28
    radius: Theme.radiusSm
    color: mouse.containsMouse ? Theme.hover : "transparent"
    Behavior on color {
        CAnim {
            duration: Theme.animFast
        }
    }

    Text {
        id: label
        anchors.centerIn: parent
        text: Keyboard.short
        color: Keyboard.short === "EN" ? Theme.text : Theme.accent
        font.family: Theme.fontSans
        font.pixelSize: Theme.fontSm
        font.weight: Font.DemiBold
        font.letterSpacing: 0.5
        Behavior on color {
            CAnim {}
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Keyboard.next()
    }
}
