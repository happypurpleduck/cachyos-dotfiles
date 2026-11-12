import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// Three floating islands: [launcher · workspaces · window]   [clock · media]   [stats · tray · keyboard · status · power]
Variants {
    model: Quickshell.screens

    PanelWindow {
        id: bar
        required property var modelData
        screen: modelData

        anchors {
            top: true
            left: true
            right: true
        }
        implicitHeight: Theme.barHeight + Theme.gap
        exclusiveZone: Theme.barHeight + Theme.gap
        color: "transparent"
        WlrLayershell.namespace: "mocha-bar"
        WlrLayershell.layer: WlrLayer.Top

        // only the islands take input; the gaps between them click through
        mask: Region {
            Region {
                item: left
            }
            Region {
                item: center
            }
            Region {
                item: right
            }
        }

        // keep-awake: the bar is always mapped, so it hosts the idle inhibitor
        IdleInhibitor {
            window: bar
            enabled: Toggles.caffeine
        }

        Island {
            id: left
            anchors.left: parent.left
            anchors.leftMargin: Theme.gap
            anchors.top: parent.top
            anchors.topMargin: Theme.gap
            padding: 5

            LauncherButton {}
            Workspaces {
                screenName: bar.modelData.name
            }
            ActiveWindow {
                Layout.maximumWidth: Math.max(0, bar.width / 2 - center.width / 2 - 260)
            }
        }

        Island {
            id: center
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Theme.gap
            padding: 14
            onClicked: Panels.toggle("calendar")

            Clock {}
            MediaChip {}
            RecordingChip {}
        }

        Island {
            id: right
            anchors.right: parent.right
            anchors.rightMargin: Theme.gap
            anchors.top: parent.top
            anchors.topMargin: Theme.gap
            padding: 5

            StatsChip {}
            Tray {
                barWindow: bar
            }
            KeyboardChip {}
            StatusIcons {}
            PowerButton {}
        }
    }
}
