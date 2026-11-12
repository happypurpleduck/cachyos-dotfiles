import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

// Red pulsing dot + elapsed time while recording; click to stop.
Rectangle {
    id: root

    visible: Recorder.recording
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 24
    radius: 12
    color: Theme.alpha(Theme.red, mouse.containsMouse ? 0.28 : 0.16)
    Layout.leftMargin: 4

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Rectangle {
            Layout.preferredWidth: 8
            Layout.preferredHeight: 8
            radius: 4
            color: Theme.red
            SequentialAnimation on opacity {
                running: Recorder.recording
                loops: Animation.Infinite
                NumberAnimation {
                    to: 0.3
                    duration: 700
                }
                NumberAnimation {
                    to: 1
                    duration: 700
                }
            }
        }
        StyledText {
            text: Recorder.fmtElapsed()
            color: Theme.red
            font.pixelSize: Theme.fontSm
            font.weight: Font.DemiBold
            font.features: ({
                    "tnum": 1
                })
        }
        MIcon {
            icon: "stop"
            size: 14
            fill: 1
            color: Theme.red
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Recorder.stop()
    }
}
