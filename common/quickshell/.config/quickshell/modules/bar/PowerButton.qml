import QtQuick
import qs.core
import qs.components

IconButton {
    implicitWidth: 28
    implicitHeight: 28
    icon: "power_settings_new"
    iconSize: 17
    onClicked: Panels.toggle("session")
}
