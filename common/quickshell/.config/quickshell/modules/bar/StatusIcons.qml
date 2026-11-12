import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

// Compact status cluster; click opens the control center, scroll = volume.
Rectangle {
    id: root

    implicitWidth: row.implicitWidth + 16
    implicitHeight: 28
    radius: Theme.radiusSm
    color: mouse.containsMouse || Panels.controlCenter ? Theme.hover : "transparent"
    Behavior on color {
        CAnim {
            duration: Theme.animFast
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10

        MIcon {
            icon: Net.icon
            size: 17
            color: Net.online ? Theme.text : Theme.overlay1
        }
        MIcon {
            visible: Net.btAvailable
            icon: Net.btIcon
            size: 17
            color: Net.btConnected.length > 0 ? Theme.accent : Net.btEnabled ? Theme.text : Theme.overlay1
        }
        MIcon {
            icon: Audio.icon
            size: 17
            color: Audio.muted ? Theme.overlay1 : Theme.text
        }
        MIcon {
            visible: Audio.micMuted
            icon: "mic_off"
            size: 17
            color: Theme.red
        }
        MIcon {
            visible: Notifs.dnd
            icon: "do_not_disturb_on"
            size: 17
            fill: 1
            color: Theme.accent
        }
        MIcon {
            visible: Toggles.caffeine
            icon: "coffee"
            size: 17
            fill: 1
            color: Theme.accent
        }
        MIcon {
            visible: Toggles.gameMode
            icon: "sports_esports"
            size: 17
            fill: 1
            color: Theme.accent
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Panels.toggle("controlCenter")
        onWheel: e => Audio.setVolume(Audio.volume + (e.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
