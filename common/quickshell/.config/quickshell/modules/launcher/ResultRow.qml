import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.core
import qs.components

// One launcher result: [icon | glyph | thumbnail]  Title / subtitle
Item {
    id: root

    required property var modelData
    required property int index
    signal clicked
    signal hovered

    implicitHeight: modelData.kind === "clip" && modelData.image ? 76 : 52

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 16
        anchors.rightMargin: 14
        spacing: 14

        Item {
            Layout.preferredWidth: root.modelData.image ? 96 : 30
            Layout.preferredHeight: root.modelData.image ? 60 : 30

            IconImage {
                anchors.fill: parent
                visible: root.modelData.kind === "app"
                source: root.modelData.kind === "app" ? Quickshell.iconPath(root.modelData.iconName || "", "application-x-executable") : ""
                asynchronous: true
            }
            Text {
                anchors.centerIn: parent
                visible: root.modelData.kind === "emoji"
                text: root.modelData.glyph ?? ""
                font.family: "Noto Color Emoji"
                font.pixelSize: 24
            }
            ClippingRectangle {
                anchors.fill: parent
                visible: !!root.modelData.image
                radius: Theme.radiusXs
                color: Theme.surface0
                Image {
                    anchors.fill: parent
                    source: root.modelData.image ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 192
                }
            }
            Rectangle {
                anchors.fill: parent
                visible: root.modelData.kind !== "app" && root.modelData.kind !== "emoji" && !root.modelData.image
                radius: Theme.radiusSm
                color: root.modelData.swatch ?? Theme.accentSoft
                MIcon {
                    anchors.centerIn: parent
                    visible: !root.modelData.swatch
                    icon: root.modelData.icon ?? "circle"
                    size: 18
                    color: Theme.accent
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1
            StyledText {
                Layout.fillWidth: true
                text: (root.modelData.title ?? "").replace(/\s+/g, " ")
                font.pixelSize: root.modelData.kind === "calc" ? Theme.fontXl : Theme.fontMd
                font.weight: root.modelData.kind === "calc" ? Font.DemiBold : Font.Medium
            }
            StyledText {
                Layout.fillWidth: true
                visible: text !== ""
                text: root.modelData.sub ?? ""
                color: Theme.textFaint
                font.pixelSize: Theme.fontSm
            }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: root.hovered()
        onClicked: root.clicked()
    }
}
