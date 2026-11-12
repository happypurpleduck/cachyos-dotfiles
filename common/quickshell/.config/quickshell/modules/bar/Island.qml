import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components

// One floating pill of the bar.
Rectangle {
    id: root

    property int padding: 6
    default property alias content: row.data
    signal clicked

    implicitWidth: row.implicitWidth + padding * 2
    implicitHeight: Theme.barHeight
    width: implicitWidth
    height: implicitHeight
    radius: Theme.radius
    color: Theme.panel
    border.width: 1
    border.color: Theme.panelBorder

    Behavior on implicitWidth {
        Anim {}
    }

    MouseArea {
        anchors.fill: parent
        onClicked: root.clicked()
    }

    RowLayout {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: root.padding
        spacing: 6
    }
}
