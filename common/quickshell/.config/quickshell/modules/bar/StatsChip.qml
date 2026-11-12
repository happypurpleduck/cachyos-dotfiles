import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components
import qs.services

// CPU · RAM · GPU usage (+ CPU temp). Values warm up to yellow/red under load.
// Shown when "Bar stats" is on in the control center; click opens btop.
Rectangle {
    id: root

    visible: Toggles.showStats
    implicitWidth: row.implicitWidth + 16
    implicitHeight: 28
    radius: Theme.radiusSm
    color: mouse.containsMouse ? Theme.hover : "transparent"
    Behavior on color {
        CAnim {
            duration: Theme.animFast
        }
    }

    function level(v) {
        return v >= 0.9 ? Theme.red : v >= 0.7 ? Theme.yellow : Theme.text;
    }
    // Fixed-width fields (the font is monospaced) so the chip doesn't change
    // width as values gain or lose digits: "  5%" / " 10%" / "100%".
    function pad(s, n) {
        return String(s).padStart(n, " ");
    }
    function pct(v) {
        return pad(Math.round(v * 100), 3) + "%";
    }
    function deg(t) {
        return pad(Math.round(t), 2) + "°";
    }

    component Stat: RowLayout {
        property string icon
        property string value
        property color tint: Theme.text
        spacing: 4
        MIcon {
            icon: parent.icon
            size: 15
            color: Theme.overlay2
        }
        StyledText {
            text: parent.value
            color: parent.tint
            font.family: Theme.fontMono
            font.pixelSize: Theme.fontSm
        }
    }

    RowLayout {
        id: row
        anchors.centerIn: parent
        spacing: 10

        Stat {
            icon: "memory"
            value: root.pct(Stats.cpu) + (Stats.cpuTemp > 0 ? " " + root.deg(Stats.cpuTemp) : "")
            tint: Stats.cpuTemp >= 85 ? Theme.red : root.level(Stats.cpu)
        }
        Stat {
            icon: "memory_alt"
            value: root.pad(Stats.memUsed.toFixed(1), 4) + "G"
            tint: root.level(Stats.mem)
        }
        Stat {
            visible: Stats.gpuName !== ""
            icon: "developer_board"
            value: root.pct(Stats.gpu) + " " + root.deg(Stats.gpuTemp)
            tint: Stats.gpuTemp >= 83 ? Theme.red : root.level(Stats.gpu)
        }
    }

    MouseArea {
        id: mouse
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: Quickshell.execDetached(["kitty", "--class", "btop", "-e", "btop"])
    }
}
