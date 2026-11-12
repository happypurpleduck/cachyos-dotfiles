import QtQuick
import QtQuick.Layouts
import qs.core
import qs.components
import qs.services

// CPU / RAM / GPU / disk as compact rings.
Card {
    RowLayout {
        Layout.fillWidth: true
        spacing: 6

        Ring {
            Layout.fillWidth: true
            label: "CPU"
            value: Stats.cpu
            detail: Stats.cpuTemp > 0 ? Math.round(Stats.cpuTemp) + "°C" : ""
        }
        Ring {
            Layout.fillWidth: true
            label: "RAM"
            value: Stats.mem
            detail: Stats.memUsed.toFixed(1) + " GiB"
        }
        Ring {
            Layout.fillWidth: true
            label: "GPU"
            value: Stats.gpu
            detail: Stats.gpuTemp > 0 ? Math.round(Stats.gpuTemp) + "°C" : ""
        }
        Ring {
            Layout.fillWidth: true
            label: "VRAM"
            value: Stats.vramTotal > 0 ? Stats.vramUsed / Stats.vramTotal : 0
            detail: Stats.vramUsed.toFixed(1) + " GiB"
        }
        Ring {
            Layout.fillWidth: true
            label: "Disk"
            value: Stats.disk
            detail: Math.round(Stats.diskTotal - Stats.diskUsed) + " GiB free"
        }
    }

    component Ring: ColumnLayout {
        id: ring
        property string label
        property real value
        property string detail
        spacing: 4

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 54
            Layout.preferredHeight: 54

            Canvas {
                id: canvas
                anchors.fill: parent
                property real v: ring.value
                property color fg: ring.value > 0.9 ? Theme.red : Theme.accent
                Behavior on v {
                    Anim {
                        duration: Theme.animSlow
                    }
                }
                onVChanged: requestPaint()
                onFgChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const r = width / 2 - 4, c = width / 2;
                    ctx.lineWidth = 5;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Theme.surface0;
                    ctx.beginPath();
                    ctx.arc(c, c, r, 0.75 * Math.PI, 2.25 * Math.PI);
                    ctx.stroke();
                    ctx.strokeStyle = fg;
                    ctx.beginPath();
                    ctx.arc(c, c, r, 0.75 * Math.PI, (0.75 + 1.5 * Math.max(0.001, Math.min(1, v))) * Math.PI);
                    ctx.stroke();
                }
            }
            StyledText {
                anchors.centerIn: parent
                text: Math.round(ring.value * 100) + "%"
                font.pixelSize: Theme.fontSm
                font.weight: Font.DemiBold
                font.features: ({
                        "tnum": 1
                    })
            }
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: ring.label
            font.pixelSize: Theme.fontXs
            font.weight: Font.DemiBold
            color: Theme.subtext1
        }
        StyledText {
            Layout.alignment: Qt.AlignHCenter
            text: ring.detail
            font.pixelSize: 10
            color: Theme.textFaint
        }
    }
}
