import QtQuick
import QtQuick.Layouts
import qs.core

// Horizontal slider: [icon] ━━━━━━○──── 62%
Item {
    id: root

    property real value: 0          // 0..1
    property string icon: ""
    property bool showValue: true
    property string valueText: Math.round(value * 100) + "%"
    property int valueWidth: 38
    property bool muted: false
    property bool enabled_: true
    signal moved(real value)
    signal iconClicked

    implicitHeight: 36
    implicitWidth: 240

    RowLayout {
        anchors.fill: parent
        spacing: Theme.spacing

        IconButton {
            visible: root.icon !== ""
            icon: root.icon
            iconColor: root.muted ? Theme.overlay1 : Theme.text
            Layout.preferredWidth: 32
            Layout.preferredHeight: 32
            onClicked: root.iconClicked()
        }

        Item {
            id: track
            Layout.fillWidth: true
            Layout.preferredHeight: 28

            readonly property real shown: drag.pressed ? drag.dragValue : root.value

            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                height: 8
                radius: 4
                color: Theme.surface0
            }
            Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(8, parent.width * Math.min(1, track.shown))
                height: 8
                radius: 4
                color: root.muted ? Theme.overlay0 : Theme.accent
                Behavior on width {
                    enabled: !drag.pressed
                    Anim {
                        duration: Theme.animFast
                    }
                }
            }
            Rectangle {
                id: knob
                x: Math.max(0, Math.min(parent.width - width, parent.width * Math.min(1, track.shown) - width / 2))
                anchors.verticalCenter: parent.verticalCenter
                width: drag.pressed || drag.containsMouse ? 18 : 14
                height: width
                radius: width / 2
                color: Theme.text
                border.width: 3
                border.color: root.muted ? Theme.overlay0 : Theme.accent
                Behavior on width {
                    Anim {
                        duration: Theme.animFast
                    }
                }
            }

            MouseArea {
                id: drag
                property real dragValue: 0
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: root.enabled_
                function update(x) {
                    dragValue = Math.max(0, Math.min(1, x / width));
                    root.moved(dragValue);
                }
                onPressed: e => update(e.x)
                onPositionChanged: e => {
                    if (pressed)
                        update(e.x);
                }
                onWheel: e => root.moved(Math.max(0, Math.min(1, root.value + (e.angleDelta.y > 0 ? 0.05 : -0.05))))
            }
        }

        StyledText {
            visible: root.showValue
            text: root.valueText
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
            font.features: ({
                    "tnum": 1
                })
            horizontalAlignment: Text.AlignRight
            Layout.preferredWidth: root.valueWidth
        }
    }
}
