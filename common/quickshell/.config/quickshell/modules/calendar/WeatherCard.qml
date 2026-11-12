import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

Card {
    visible: Weather.ready

    RowLayout {
        Layout.fillWidth: true
        spacing: 14

        MIcon {
            icon: Weather.icon
            size: 44
            fill: 1
            color: Theme.accent
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            RowLayout {
                spacing: 8
                StyledText {
                    text: Weather.temp + "°"
                    font.pixelSize: 28
                    font.weight: Font.DemiBold
                }
                StyledText {
                    Layout.alignment: Qt.AlignBottom
                    Layout.bottomMargin: 5
                    text: "feels " + Weather.feels + "°"
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontSm
                }
            }
            StyledText {
                Layout.fillWidth: true
                text: Weather.desc
                color: Theme.textMuted
                font.pixelSize: Theme.fontSm
            }
            StyledText {
                Layout.fillWidth: true
                visible: Weather.location !== ""
                text: Weather.location
                color: Theme.textFaint
                font.pixelSize: Theme.fontXs
            }
        }

        Repeater {
            model: Weather.forecast
            ColumnLayout {
                required property var modelData
                spacing: 2
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: parent.modelData.day
                    color: Theme.textFaint
                    font.pixelSize: Theme.fontXs
                }
                MIcon {
                    Layout.alignment: Qt.AlignHCenter
                    icon: parent.modelData.icon
                    size: 18
                    color: Theme.subtext1
                }
                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    text: parent.modelData.high + "° " + parent.modelData.low + "°"
                    font.pixelSize: Theme.fontXs
                    color: Theme.subtext1
                }
            }
        }
    }
}
