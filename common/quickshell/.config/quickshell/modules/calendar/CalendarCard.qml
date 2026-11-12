import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components

// Month grid, Sunday-first (Fri/Sat weekend), today in the accent. Scroll or arrows to change month.
Card {
    id: root

    property int offset: 0
    readonly property date today: clock.date
    readonly property date shown: new Date(today.getFullYear(), today.getMonth() + offset, 1)
    readonly property var cells: {
        const first = shown.getDay();                      // Sunday = 0
        const days = new Date(shown.getFullYear(), shown.getMonth() + 1, 0).getDate();
        const prevDays = new Date(shown.getFullYear(), shown.getMonth(), 0).getDate();
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = i - first + 1;
            if (d < 1)
                out.push({
                    day: prevDays + d,
                    inMonth: false,
                    today: false
                });
            else if (d > days)
                out.push({
                    day: d - days,
                    inMonth: false,
                    today: false
                });
            else
                out.push({
                    day: d,
                    inMonth: true,
                    today: offset === 0 && d === today.getDate()
                });
        }
        return out;
    }

    SystemClock {
        id: clock
        precision: SystemClock.Hours
    }

    Connections {
        target: Panels
        function onCalendarChanged() {
            root.offset = 0;
        }
    }

    RowLayout {
        Layout.fillWidth: true
        StyledText {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            text: Qt.formatDate(root.shown, "MMMM yyyy")
            font.pixelSize: Theme.fontLg
            font.weight: Font.DemiBold
        }
        // "back to today" sits left of the arrows and always keeps its space,
        // so the arrows never move when it fades in
        IconButton {
            implicitWidth: 28
            implicitHeight: 28
            icon: "today"
            iconSize: 16
            enabled: root.offset !== 0
            opacity: enabled ? 1 : 0
            Behavior on opacity {
                Anim {
                    duration: Theme.animFast
                }
            }
            onClicked: root.offset = 0
        }
        IconButton {
            implicitWidth: 28
            implicitHeight: 28
            icon: "chevron_left"
            onClicked: root.offset--
        }
        IconButton {
            implicitWidth: 28
            implicitHeight: 28
            icon: "chevron_right"
            onClicked: root.offset++
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
            StyledText {
                required property string modelData
                required property int index
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: modelData
                font.pixelSize: Theme.fontXs
                font.weight: Font.DemiBold
                color: index >= 5 ? Theme.accent : Theme.textFaint   // Fri + Sat weekend
            }
        }
        Repeater {
            model: root.cells
            Rectangle {
                required property var modelData
                Layout.fillWidth: true
                Layout.preferredHeight: 30
                radius: Theme.radiusSm
                color: modelData.today ? Theme.accent : "transparent"
                StyledText {
                    anchors.centerIn: parent
                    text: parent.modelData.day
                    font.pixelSize: Theme.fontSm
                    font.weight: parent.modelData.today ? Font.Bold : Font.Normal
                    font.features: ({
                            "tnum": 1
                        })
                    color: parent.modelData.today ? Theme.onAccent : parent.modelData.inMonth ? Theme.text : Theme.surface2
                }
            }
        }
    }

    WheelHandler {
        onWheel: e => root.offset += e.angleDelta.y > 0 ? -1 : 1
    }
}
