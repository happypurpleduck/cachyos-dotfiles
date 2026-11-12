import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components
import qs.services

Card {
    id: card
    padding: 10

    // collapses again whenever the control center closes
    readonly property bool picking: Panels.soundPicker
    Connections {
        target: Panels
        function onControlCenterChanged() {
            if (!Panels.controlCenter)
                Panels.soundPicker = false;
        }
    }

    // header: [current output ▾]            [effects] [mixer]
    RowLayout {
        Layout.fillWidth: true
        spacing: 4

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 30
            radius: Theme.radiusSm
            color: devMouse.containsMouse || card.picking ? Theme.hover : "transparent"
            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                spacing: 8
                MIcon {
                    icon: "headphones"
                    size: 16
                    color: Theme.textMuted
                }
                StyledText {
                    Layout.fillWidth: true
                    text: Audio.sinkName
                    color: Theme.textMuted
                    font.pixelSize: Theme.fontSm
                }
                MIcon {
                    icon: "expand_more"
                    size: 18
                    color: Theme.textMuted
                    rotation: card.picking ? 180 : 0
                    Behavior on rotation {
                        Anim {
                            duration: Theme.animFast
                        }
                    }
                }
            }
            MouseArea {
                id: devMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.soundPicker = !Panels.soundPicker
            }
        }
        IconButton {
            implicitWidth: 30
            implicitHeight: 30
            icon: "graphic_eq"
            iconSize: 17
            iconColor: AudioFx.eq || AudioFx.nc ? Theme.accent : Theme.text
            onClicked: Panels.toggle("audioFx")
        }
        IconButton {
            implicitWidth: 30
            implicitHeight: 30
            icon: "tune"
            iconSize: 17
            onClicked: {
                Panels.controlCenter = false;
                Quickshell.execDetached(["pavucontrol"]);
            }
        }
    }

    // device picker: outputs then inputs; click to make it the default
    ColumnLayout {
        Layout.fillWidth: true
        visible: card.picking
        spacing: 0
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.topMargin: 4
            text: "OUTPUT"
            font.pixelSize: Theme.fontXs
            font.weight: Font.DemiBold
            color: Theme.textFaint
        }
        Repeater {
            model: Audio.sinks
            DeviceRow {
                required property var modelData
                node: modelData
                current: modelData === Audio.sink
                onPicked: Audio.setDefaultSink(modelData)
            }
        }
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 8
            Layout.topMargin: 4
            text: "INPUT"
            font.pixelSize: Theme.fontXs
            font.weight: Font.DemiBold
            color: Theme.textFaint
        }
        Repeater {
            model: Audio.sources
            DeviceRow {
                required property var modelData
                node: modelData
                current: modelData === Audio.source
                onPicked: Audio.setDefaultSource(modelData)
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Layout.bottomMargin: 2
            implicitHeight: 1
            color: Theme.surface0
        }
    }

    StyledSlider {
        Layout.fillWidth: true
        icon: Audio.icon
        value: Audio.volume
        muted: Audio.muted
        onMoved: v => Audio.setVolume(v)
        onIconClicked: Audio.toggleMute()
    }
    StyledSlider {
        Layout.fillWidth: true
        icon: Audio.micIcon
        value: Audio.micVolume
        muted: Audio.micMuted
        onMoved: v => Audio.setMicVolume(v)
        onIconClicked: Audio.toggleMicMute()
    }
    StyledSlider {
        Layout.fillWidth: true
        visible: Brightness.available
        icon: "brightness_6"
        value: Brightness.value
        onMoved: v => Brightness.set(v)
    }
}
