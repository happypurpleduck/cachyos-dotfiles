import QtQuick
import QtQuick.Layouts
import qs.core

// Inset section inside a panel (control center, calendar).
Rectangle {
    id: root

    default property alias content: inner.data
    property int padding: 14

    Layout.fillWidth: true
    implicitHeight: inner.implicitHeight + padding * 2
    radius: Theme.radius
    color: Theme.alpha(Theme.mantle, 0.85)
    border.width: 1
    border.color: Theme.alpha(Theme.surface0, 0.8)

    ColumnLayout {
        id: inner
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: root.padding
        spacing: 10
    }
}
