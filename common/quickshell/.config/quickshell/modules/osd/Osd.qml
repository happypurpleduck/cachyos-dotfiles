import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.components
import qs.services

// Volume / mic / brightness pill near the bottom of the screen. Click-through.
PanelWindow {
    id: osd

    property string kind: "volume"      // volume | mic | brightness | micall (F22)
    property bool allMuted: false
    property bool shown: false
    property bool armed: false          // ignore the initial values at startup

    screen: Panels.activeScreen
    // The window is larger than the pill so its soft shadow has room to fade out
    // (a tight window clipped the shadow into a hard dark box).
    readonly property int shadowRoom: 40
    anchors.bottom: true
    margins.bottom: 72 - shadowRoom
    implicitWidth: 300 + shadowRoom * 2
    implicitHeight: 44 + shadowRoom * 2
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    visible: shown || card.opacity > 0
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "mocha-osd"

    function show(k) {
        if (!armed)
            return;
        kind = k;
        shown = true;
        hide.restart();
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: osd.armed = true
    }
    Timer {
        id: hide
        interval: 1400
        onTriggered: osd.shown = false
    }

    Connections {
        target: Audio
        function onVolumeChanged() {
            osd.show("volume");
        }
        function onMutedChanged() {
            osd.show("volume");
        }
        function onMicMutedChanged() {
            if (!AudioFx.mutingMics && !(osd.kind === "micall" && osd.shown))
                osd.show("mic");
        }
    }
    Connections {
        target: AudioFx
        function onMicsToggled(muted) {
            osd.allMuted = muted;
            osd.show("micall");
        }
    }
    Connections {
        target: Brightness
        function onChangedByUser() {
            osd.show("brightness");
        }
    }

    readonly property bool micAll: kind === "micall"
    readonly property real value: kind === "volume" ? Audio.volume : kind === "mic" ? Audio.micVolume : Brightness.value
    readonly property bool off: kind === "volume" ? Audio.muted : kind === "mic" ? Audio.micMuted : kind === "micall" ? allMuted : false
    readonly property string icon: kind === "micall" ? (allMuted ? "mic_off" : "mic") : kind === "volume" ? Audio.icon : kind === "mic" ? Audio.micIcon : (Brightness.value < 0.4 ? "brightness_5" : Brightness.value < 0.75 ? "brightness_6" : "brightness_7")

    Surface {
        id: card
        anchors.fill: parent
        anchors.margins: osd.shadowRoom
        radius: height / 2
        opacity: osd.shown ? 1 : 0
        scale: osd.shown ? 1 : 0.92
        Behavior on opacity {
            Anim {
                duration: Theme.animFast
            }
        }
        Behavior on scale {
            Anim {}
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 18
            spacing: 12

            MIcon {
                icon: osd.icon
                size: 20
                fill: 1
                color: osd.micAll ? (osd.allMuted ? Theme.red : Theme.green) : osd.off ? Theme.overlay1 : Theme.accent
            }
            StyledText {
                visible: osd.micAll
                Layout.fillWidth: true
                text: osd.allMuted ? "All microphones muted" : "Microphones live"
                font.pixelSize: Theme.fontMd
                font.weight: Font.DemiBold
                color: osd.allMuted ? Theme.red : Theme.text
            }
            Item {
                visible: !osd.micAll
                Layout.fillWidth: true
                Layout.preferredHeight: 6
                Rectangle {
                    anchors.fill: parent
                    radius: 3
                    color: Theme.surface0
                }
                Rectangle {
                    width: parent.width * Math.min(1, osd.value)
                    height: parent.height
                    radius: 3
                    color: osd.off ? Theme.overlay0 : Theme.accent
                    Behavior on width {
                        Anim {
                            duration: Theme.animFast
                        }
                    }
                }
            }
            StyledText {
                visible: !osd.micAll
                text: osd.off ? "Muted" : Math.round(osd.value * 100) + "%"
                font.pixelSize: Theme.fontSm
                font.weight: Font.DemiBold
                font.features: ({
                        "tnum": 1
                    })
                color: Theme.subtext1
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 44
            }
        }
    }
}
