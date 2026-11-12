import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components

RowLayout {
    spacing: 8

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    StyledText {
        text: Qt.formatDateTime(clock.date, "HH:mm:ss")
        font.pixelSize: Theme.fontLg
        font.weight: Font.DemiBold
        font.features: ({
                "tnum": 1
            })
    }
    Rectangle {
        Layout.preferredWidth: 4
        Layout.preferredHeight: 4
        radius: 2
        color: Theme.accent
    }
    StyledText {
        text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
        color: Theme.textMuted
        font.pixelSize: Theme.fontMd
    }
}
