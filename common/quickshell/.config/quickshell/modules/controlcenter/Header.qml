import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets
import qs.core
import qs.components
import qs.services

RowLayout {
    Layout.fillWidth: true
    spacing: 12

    // avatar: ~/.face if present, otherwise an accent initial
    ClippingRectangle {
        Layout.preferredWidth: 44
        Layout.preferredHeight: 44
        radius: 22
        color: Theme.accent
        Image {
            id: face
            anchors.fill: parent
            source: "file://" + Session.face
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            sourceSize.width: 88
        }
        StyledText {
            anchors.centerIn: parent
            visible: face.status !== Image.Ready
            text: Session.user.charAt(0).toUpperCase()
            color: Theme.onAccent
            font.pixelSize: 20
            font.weight: Font.Bold
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 0
        StyledText {
            text: Session.user
            font.pixelSize: Theme.fontLg
            font.weight: Font.DemiBold
        }
        StyledText {
            text: "up " + Stats.fmtUptime() + "  ·  " + Theme.accentName
            color: Theme.textMuted
            font.pixelSize: Theme.fontSm
        }
    }

    IconButton {
        icon: "notifications"
        tooltip: "Notification settings"
        onClicked: {
            Panels.controlCenter = false;
            Notifs.openSettings();
        }
    }
    IconButton {
        icon: "lock"
        onClicked: Session.lock()
    }
    IconButton {
        icon: "power_settings_new"
        onClicked: Panels.toggle("session")
    }
}
