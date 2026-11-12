import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

// One output/input device in the sound card's picker; current = radio filled.
Rectangle {
    id: row
    required property var node
    property bool current
    signal picked
    Layout.fillWidth: true
    implicitHeight: 30
    radius: Theme.radiusSm
    color: rowMouse.containsMouse ? Theme.hover : "transparent"
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        spacing: 10
        MIcon {
            icon: row.current ? "radio_button_checked" : "radio_button_unchecked"
            size: 16
            fill: row.current ? 1 : 0
            color: row.current ? Theme.accent : Theme.overlay1
        }
        StyledText {
            Layout.fillWidth: true
            text: Audio.nodeLabel(row.node)
            font.pixelSize: Theme.fontSm
            color: row.current ? Theme.text : Theme.subtext0
        }
    }
    MouseArea {
        id: rowMouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.picked()
    }
}
