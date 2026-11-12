import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.core
import qs.components
import qs.services

// Audio effects: Chu 2 AutoEq + mic noise suppression with its dials.
// Opened from the › on the control center's AutoEq / Noise suppression tiles.
OverlayWindow {
    id: win

    name: "audiofx"
    open: Panels.audioFx
    dim: 0
    onDismissed: Panels.audioFx = false
    onOpenChanged: {
        if (open)
            AudioFx.refresh();
        else
            monitor.running = false;
    }

    // "Hear yourself": loop the (cleaned) mic to the output while tuning
    Process {
        id: monitor
        command: ["pw-loopback", "--capture-props=node.name=mocha-mic-monitor node.description=Mic\\ monitor", "--playback-props=node.name=mocha-mic-monitor-out media.role=Communication"]
    }

    component SectionHead: RowLayout {
        id: head
        property string icon
        property string title
        property string subtitle
        property bool checked
        signal toggled
        Layout.fillWidth: true
        spacing: 12
        MIcon {
            icon: head.icon
            size: 22
            fill: head.checked ? 1 : 0
            color: head.checked ? Theme.accent : Theme.textMuted
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0
            StyledText {
                Layout.fillWidth: true
                text: head.title
                font.weight: Font.DemiBold
            }
            StyledText {
                Layout.fillWidth: true
                text: head.subtitle
                color: Theme.textMuted
                font.pixelSize: Theme.fontXs
            }
        }
        ToggleSwitch {
            checked: head.checked
            onToggled: head.toggled()
        }
    }

    // label + hint above a slider
    component Dial: ColumnLayout {
        id: dial
        property string label
        property string hint
        property real value       // 0..1
        property string valueText
        signal moved(real v)
        Layout.fillWidth: true
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 4
            StyledText {
                text: dial.label
                font.pixelSize: Theme.fontSm
            }
            StyledText {
                Layout.fillWidth: true
                text: dial.hint
                color: Theme.textFaint
                font.pixelSize: Theme.fontXs
                horizontalAlignment: Text.AlignRight
            }
        }
        StyledSlider {
            Layout.fillWidth: true
            implicitHeight: 30
            value: dial.value
            valueText: dial.valueText
            valueWidth: 64
            onMoved: v => dial.moved(v)
        }
    }

    Surface {
        id: card
        width: 440
        height: col.implicitHeight + 28
        anchors.right: parent.right
        anchors.rightMargin: Theme.gap
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

            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                IconButton {
                    icon: "arrow_back"
                    iconSize: 18
                    onClicked: Panels.toggle("controlCenter")
                }
                StyledText {
                    Layout.fillWidth: true
                    text: "Audio effects"
                    font.pixelSize: Theme.fontLg
                    font.weight: Font.DemiBold
                }
            }

            // ── Output ──────────────────────────────────────────────
            Card {
                visible: AudioFx.eqAvailable
                SectionHead {
                    icon: "graphic_eq"
                    title: "AutoEq"
                    subtitle: AudioFx.eqProfile + (AudioFx.eqDevice ? " · only when playing to " + AudioFx.eqDevice : "")
                    checked: AudioFx.eq
                    onToggled: AudioFx.toggleEq()
                }
            }

            // ── Microphone ──────────────────────────────────────────
            Card {
                SectionHead {
                    icon: "noise_control_off"
                    title: "Noise suppression"
                    subtitle: "RNNoise · " + Audio.sourceName
                    checked: AudioFx.nc
                    onToggled: AudioFx.toggleNc()
                }

                StyledSlider {
                    Layout.fillWidth: true
                    valueWidth: 64
                    icon: Audio.micIcon
                    value: Audio.micVolume
                    muted: Audio.micMuted
                    onMoved: v => Audio.setMicVolume(v)
                    onIconClicked: Audio.toggleMicMute()
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 6
                    enabled: AudioFx.nc
                    opacity: AudioFx.nc ? 1 : 0.4
                    Behavior on opacity {
                        Anim {}
                    }

                    Dial {
                        label: "Strength"
                        hint: "lower blends your raw mic back in"
                        value: AudioFx.strength / 100
                        valueText: Math.round(AudioFx.strength) + "%"
                        onMoved: v => AudioFx.set("strength", v * 100)
                    }
                    Dial {
                        label: "Voice gate"
                        hint: "higher = more silence between words"
                        value: AudioFx.threshold / 99
                        valueText: Math.round(AudioFx.threshold) + "%"
                        onMoved: v => AudioFx.set("threshold", v * 99)
                    }
                    Dial {
                        label: "Hold"
                        hint: "keeps the gate open after you speak"
                        value: AudioFx.grace / 1000
                        valueText: Math.round(AudioFx.grace) + " ms"
                        onMoved: v => AudioFx.set("grace", Math.round(v * 20) * 50)
                    }
                    Dial {
                        label: "Lookback"
                        hint: "saves word starts · adds this much delay"
                        value: AudioFx.retro / 200
                        valueText: Math.round(AudioFx.retro) + " ms"
                        onMoved: v => AudioFx.set("retro", Math.round(v * 20) * 10)
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 34
                            radius: Theme.radiusSm
                            color: monitor.running ? Theme.accent : (hearMouse.containsMouse ? Theme.surface1 : Theme.surface0)
                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 8
                                MIcon {
                                    icon: "hearing"
                                    size: 17
                                    color: monitor.running ? Theme.onAccent : Theme.text
                                }
                                StyledText {
                                    text: monitor.running ? "Listening to your mic…" : "Hear yourself"
                                    font.pixelSize: Theme.fontSm
                                    color: monitor.running ? Theme.onAccent : Theme.text
                                }
                            }
                            MouseArea {
                                id: hearMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: monitor.running = !monitor.running
                            }
                        }
                        Rectangle {
                            implicitWidth: resetRow.implicitWidth + 24
                            implicitHeight: 34
                            radius: Theme.radiusSm
                            color: resetMouse.containsMouse ? Theme.surface1 : Theme.surface0
                            RowLayout {
                                id: resetRow
                                anchors.centerIn: parent
                                spacing: 6
                                MIcon {
                                    icon: "restart_alt"
                                    size: 17
                                }
                                StyledText {
                                    text: "Defaults"
                                    font.pixelSize: Theme.fontSm
                                }
                            }
                            MouseArea {
                                id: resetMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    AudioFx.set("strength", 100);
                                    AudioFx.set("threshold", 50);
                                    AudioFx.set("grace", 200);
                                    AudioFx.set("retro", 0);
                                }
                            }
                        }
                    }
                }
            }

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: 4
                text: "F22 mutes / unmutes every microphone"
                color: Theme.textFaint
                font.pixelSize: Theme.fontXs
            }
        }
    }
}
