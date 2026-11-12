import QtQuick
import qs.core

// Dialog action button; `primary` = accent-filled.
Rectangle {
    id: b

    property string text
    property bool primary: false
    signal clicked

    implicitWidth: label.implicitWidth + 32
    implicitHeight: 38
    radius: Theme.radiusSm
    color: primary ? (m.containsMouse ? Theme.mix(Theme.accent, Theme.text, 0.15) : Theme.accent) : (m.containsMouse ? Theme.surface1 : Theme.surface0)

    StyledText {
        id: label
        anchors.centerIn: parent
        text: b.text
        font.weight: Font.DemiBold
        color: b.primary ? Theme.onAccent : Theme.text
    }
    MouseArea {
        id: m
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: b.clicked()
    }
}
