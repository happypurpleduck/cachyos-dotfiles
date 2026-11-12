import QtQuick
import QtQuick.Effects
import qs.core

// Panel background used by every popup: Mocha base, hairline border, soft shadow.
Item {
    id: root

    property real radius: Theme.radius
    property color color: Theme.panel
    property bool shadow: true
    default property alias content: inner.data

    RectangularShadow {
        anchors.fill: bg
        visible: root.shadow
        radius: root.radius
        blur: 28
        spread: 0
        offset: Qt.vector2d(0, 6)
        color: Theme.alpha(Theme.crust, 0.55)
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        radius: root.radius
        color: root.color
        border.width: 1
        border.color: Theme.panelBorder
    }

    Item {
        id: inner
        anchors.fill: parent
    }
}
