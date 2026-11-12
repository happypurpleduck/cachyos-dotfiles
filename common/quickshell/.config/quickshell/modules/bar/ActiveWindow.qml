import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import Quickshell.Widgets
import qs.core
import qs.components

// Icon + title of the focused window.
RowLayout {
    id: root

    readonly property var toplevel: Hyprland.activeToplevel
    readonly property string appClass: toplevel?.lastIpcObject?.class ?? ""
    readonly property string title: toplevel?.title ?? ""

    visible: title !== "" && Layout.maximumWidth > 60
    spacing: 8
    Layout.rightMargin: 8

    Rectangle {
        Layout.preferredWidth: 1
        Layout.preferredHeight: 16
        color: Theme.surface1
    }

    IconImage {
        Layout.preferredWidth: 16
        Layout.preferredHeight: 16
        source: Hypr.iconFor(root.appClass)
        asynchronous: true
    }

    StyledText {
        Layout.fillWidth: true
        Layout.maximumWidth: Math.max(0, root.Layout.maximumWidth - 40)
        text: root.title
        color: Theme.textMuted
        font.pixelSize: Theme.fontSm
    }
}
