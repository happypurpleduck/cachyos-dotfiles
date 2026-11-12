import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

// Now playing: blurred album art backdrop, art, title, progress, controls.
Card {
    id: root

    visible: Media.hasPlayer
    padding: 12
    clip: true

    ClippingRectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 112
        radius: Theme.radiusSm
        color: Theme.surface0

        Image {
            id: bgArt
            anchors.fill: parent
            source: Media.artUrl
            fillMode: Image.PreserveAspectCrop
            visible: false
            asynchronous: true
            sourceSize.width: 256
        }
        MultiEffect {
            anchors.fill: parent
            source: bgArt
            visible: bgArt.status === Image.Ready
            blurEnabled: true
            blur: 1
            blurMax: 48
            saturation: 0.2
            brightness: -0.35
        }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 14

            ClippingRectangle {
                Layout.preferredWidth: 88
                Layout.preferredHeight: 88
                radius: Theme.radiusSm
                color: Theme.surface1
                Image {
                    id: art
                    anchors.fill: parent
                    source: Media.artUrl
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 176
                }
                MIcon {
                    anchors.centerIn: parent
                    visible: art.status !== Image.Ready
                    icon: "music_note"
                    size: 32
                    color: Theme.overlay1
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                StyledText {
                    Layout.fillWidth: true
                    text: Media.title || "Nothing playing"
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Media.artist || Media.active?.identity || ""
                    color: Theme.subtext1
                    font.pixelSize: Theme.fontSm
                }
                Item {
                    Layout.fillHeight: true
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 4
                    IconButton {
                        icon: "skip_previous"
                        onClicked: Media.previous()
                    }
                    IconButton {
                        icon: Media.playing ? "pause" : "play_arrow"
                        active: true
                        onClicked: Media.toggle()
                    }
                    IconButton {
                        icon: "skip_next"
                        onClicked: Media.next()
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    IconButton {
                        visible: Media.players.length > 1
                        icon: "swap_horiz"
                        onClicked: Media.cycle()
                    }
                }
            }
        }
    }

    // progress
    RowLayout {
        Layout.fillWidth: true
        visible: Media.length > 0
        spacing: 10
        StyledText {
            text: Media.fmt(Media.position)
            color: Theme.textFaint
            font.pixelSize: Theme.fontXs
            font.features: ({
                    "tnum": 1
                })
        }
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 14
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 4
                radius: 2
                color: Theme.surface0
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width * Math.min(1, Media.position / Math.max(1, Media.length))
                height: 4
                radius: 2
                color: Theme.accent
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: e => Media.seek(e.x / width)
            }
        }
        StyledText {
            text: Media.fmt(Media.length)
            color: Theme.textFaint
            font.pixelSize: Theme.fontXs
            font.features: ({
                    "tnum": 1
                })
        }
    }
}
