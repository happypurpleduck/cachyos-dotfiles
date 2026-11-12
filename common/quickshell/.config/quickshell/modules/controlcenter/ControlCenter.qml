import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

// Drop-down from the top-right island.
OverlayWindow {
    id: win

    name: "controlcenter"
    open: Panels.controlCenter
    dim: 0
    onDismissed: Panels.controlCenter = false

    Surface {
        id: card
        width: 440
        height: Math.min(col.implicitHeight + 28, win.height - Theme.barHeight - Theme.gap * 3)
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
        y: Theme.barHeight + Theme.gap * 2 - (1 - win.progress) * 16
        opacity: win.progress

        MouseArea {
            anchors.fill: parent
        }

        Flickable {
            anchors.fill: parent
            anchors.margins: 14
            contentHeight: col.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ColumnLayout {
                id: col
                width: parent.width
                spacing: 10

                Header {}
                TogglesGrid {}
                SlidersCard {}
                MediaCard {}
                // the bar already shows these while "Bar stats" is on
                StatsCard {
                    visible: !Toggles.showStats
                }
                AccentCard {}
            }
        }
    }
}
