import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

// "▶ Artist — Title" in the centre island while something is playing.
RowLayout {
    id: root

    visible: Media.hasPlayer && Media.title !== "" && Media.playing
    spacing: 6

    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        Layout.leftMargin: 4
        Layout.rightMargin: 4
        color: Theme.surface1
    }

    // three tiny equaliser bars
    Row {
        spacing: 2
        Layout.alignment: Qt.AlignVCenter
        Layout.preferredHeight: 12
        Repeater {
            model: 3
            Rectangle {
                required property int index
                width: 3
                radius: 1.5
                anchors.bottom: parent.bottom
                color: Theme.accent
                height: 4
                SequentialAnimation on height {
                    running: Media.playing
                    loops: Animation.Infinite
                    NumberAnimation {
                        to: 12 - index * 2
                        duration: 380 + index * 90
                        easing.type: Easing.InOutSine
                    }
                    NumberAnimation {
                        to: 4
                        duration: 380 + index * 90
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
    }

    StyledText {
        Layout.maximumWidth: 260
        text: Media.artist ? `${Media.title}  ·  ${Media.artist}` : Media.title
        font.pixelSize: Theme.fontSm
        color: Theme.subtext1
    }
}
