import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components

// Drop-down under the centre pill (clock/date): today at a glance, month grid, weather.
OverlayWindow {
    id: win

    name: "calendar"
    open: Panels.calendar
    dim: 0
    onDismissed: Panels.calendar = false

    SystemClock {
        id: clock
        precision: SystemClock.Seconds
    }

    // ISO-8601 week number
    function isoWeek(d) {
        const t = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
        const day = t.getUTCDay() || 7;
        t.setUTCDate(t.getUTCDate() + 4 - day);
        const y0 = new Date(Date.UTC(t.getUTCFullYear(), 0, 1));
        return Math.ceil(((t - y0) / 86400000 + 1) / 7);
    }

    Surface {
        id: card
        width: 420
        height: col.implicitHeight + 28
        anchors.horizontalCenter: parent.horizontalCenter
        y: Theme.barHeight + Theme.gap * 2 - (1 - win.progress) * 16
        opacity: win.progress

        MouseArea {
            anchors.fill: parent
        }

        ColumnLayout {
            id: col
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 14
            spacing: 12

            // today
            RowLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 6
                Layout.rightMargin: 6
                Layout.topMargin: 4
                spacing: 14

                StyledText {
                    text: Qt.formatDateTime(clock.date, "HH:mm")
                    font.pixelSize: 40
                    font.weight: Font.DemiBold
                    font.features: ({
                            "tnum": 1
                        })
                    StyledText {
                        anchors.left: parent.right
                        anchors.leftMargin: 3
                        anchors.baseline: parent.baseline
                        text: Qt.formatDateTime(clock.date, "ss")
                        color: Theme.accent
                        font.pixelSize: Theme.fontMd
                        font.weight: Font.DemiBold
                        font.features: ({
                                "tnum": 1
                            })
                    }
                }
                Item {
                    Layout.preferredWidth: 18
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.formatDate(clock.date, "dddd")
                        font.pixelSize: Theme.fontLg
                        font.weight: Font.DemiBold
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: Qt.formatDate(clock.date, "d MMMM yyyy")
                        color: Theme.textMuted
                        font.pixelSize: Theme.fontSm
                    }
                    StyledText {
                        Layout.fillWidth: true
                        text: "Week " + win.isoWeek(clock.date)
                        color: Theme.textFaint
                        font.pixelSize: Theme.fontXs
                    }
                }
            }

            CalendarCard {}
            WeatherCard {}
        }
    }
}
