import QtQuick
import QtQuick.Layouts
import qs.core

// Control-center tile (3 per row): icon on top, label + state line below.
// Accent-filled when active. `more` adds a › button that opens a detail popup.
Rectangle {
    id: root

    property string icon: ""
    property string label: ""
    property string sublabel: ""
    property bool active: false
    property bool more: false
    signal clicked
    signal rightClicked
    signal moreClicked

    implicitHeight: 74
    radius: Theme.radius
    color: active ? Theme.accent : (mouse.containsMouse ? Theme.surface1 : Theme.surface0)
    Behavior on color {
        CAnim {}
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onClicked: e => e.button === Qt.RightButton ? root.rightClicked() : root.clicked()
    }

    MIcon {
        x: 12
        y: 11
        icon: root.icon
        size: 20
        fill: root.active ? 1 : 0
        color: root.active ? Theme.onAccent : Theme.text
    }

    Rectangle {
        visible: root.more
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 6
        width: 28
        height: 28
        radius: Theme.radiusSm
        color: moreMouse.containsMouse ? (root.active ? Theme.alpha(Theme.onAccent, 0.14) : Theme.hover) : "transparent"
        MIcon {
            anchors.centerIn: parent
            icon: "chevron_right"
            size: 18
            color: root.active ? Theme.onAccent : Theme.textMuted
        }
        MouseArea {
            id: moreMouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.moreClicked()
        }
    }

    ColumnLayout {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.leftMargin: 12
        anchors.rightMargin: 8
        anchors.bottomMargin: 9
        spacing: 0
        StyledText {
            Layout.fillWidth: true
            text: root.label
            font.pixelSize: Theme.fontSm
            font.weight: Font.DemiBold
            color: root.active ? Theme.onAccent : Theme.text
        }
        StyledText {
            Layout.fillWidth: true
            visible: text !== ""
            text: root.sublabel
            font.pixelSize: Theme.fontXs
            color: root.active ? Theme.alpha(Theme.onAccent, 0.75) : Theme.textMuted
        }
    }
}
