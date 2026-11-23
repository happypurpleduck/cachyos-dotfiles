import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.core
import qs.components

// Wallpaper + accent: current wallpaper preview, shuffle/pick, and the 14
// Catppuccin accents (click = manual override, "Auto" = follow wallpaper).
Card {
    RowLayout {
        Layout.fillWidth: true
        spacing: 12

        ClippingRectangle {
            Layout.preferredWidth: 112
            Layout.preferredHeight: 63
            radius: Theme.radiusSm
            color: Theme.surface0
            Image {
                anchors.fill: parent
                source: Theme.wallpaper ? Theme.thumbUrl(Theme.wallpaper.split("/").pop()) : ""
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
            }
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: Panels.openLauncher("@")
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            StyledText {
                Layout.fillWidth: true
                text: Theme.wallpaper.split("/").pop().replace(/\.[^.]+$/, "")
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.fillWidth: true
                text: Theme.accentName + (Theme.accentMode === "auto" ? " · auto" : " · manual")
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
            }
        }

        IconButton {
            icon: "auto_awesome"
            active: Theme.accentMode === "auto"
            onClicked: Theme.setAccent("auto")
        }
        IconButton {
            icon: "shuffle"
            onClicked: Theme.themeCmd(["random"])
        }
        IconButton {
            icon: "wallpaper"
            onClicked: Panels.openLauncher("@")
        }
    }

    // the 14 accents in one row, evenly spread
    RowLayout {
        Layout.fillWidth: true
        spacing: 0

        Repeater {
            model: Theme.accentNames
            Item {
                id: cell
                required property string modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                Rectangle {
                    id: sw
                    readonly property string modelData: cell.modelData
                    readonly property bool current: Theme.accentName === modelData
                    anchors.centerIn: parent
                    width: 22
                    height: 22
                    radius: 11
                    color: Theme[modelData]
                    border.width: current ? 2 : 0
                    border.color: Theme.text
                    scale: hov.containsMouse ? 1.15 : 1
                    Behavior on scale {
                        Anim {
                            duration: Theme.animFast
                        }
                    }
                    MIcon {
                        anchors.centerIn: parent
                        visible: sw.current
                        icon: "check"
                        size: 14
                        weight: 700
                        color: Theme.crust
                    }
                    MouseArea {
                        id: hov
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Theme.setAccent(sw.modelData)
                    }
                }
            }
        }
    }
}
