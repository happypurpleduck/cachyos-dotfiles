import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.core
import qs.components
import qs.services

GridLayout {
    Layout.fillWidth: true
    columns: 3
    columnSpacing: 8
    rowSpacing: 8

    QuickToggle {
        Layout.fillWidth: true
        icon: Net.icon
        label: Net.wired ? "Ethernet" : Net.hasWifi ? "Wi-Fi" : "Network"
        sublabel: Net.wired ? "Connected" : Net.label
        active: Net.online
        onClicked: if (Net.hasWifi)
            Net.toggleWifi()
    }
    QuickToggle {
        Layout.fillWidth: true
        icon: Net.btIcon
        label: "Bluetooth"
        sublabel: Net.btLabel
        active: Net.btEnabled
        more: Net.btAvailable
        onClicked: Net.toggleBluetooth()
        onMoreClicked: Panels.toggle("bluetooth")
    }
    QuickToggle {
        Layout.fillWidth: true
        icon: Notifs.dnd ? "do_not_disturb_on" : "notifications"
        label: "Do not disturb"
        sublabel: Notifs.dnd ? "On" : "Off"
        active: Notifs.dnd
        onClicked: Notifs.toggleDnd()
    }
    QuickToggle {
        Layout.fillWidth: true
        icon: "coffee"
        label: "Keep awake"
        sublabel: Toggles.caffeine ? "Idle paused" : "Off"
        active: Toggles.caffeine
        onClicked: Toggles.toggleCaffeine()
    }
    QuickToggle {
        Layout.fillWidth: true
        icon: "nightlight"
        label: "Night light"
        sublabel: Toggles.nightLight ? Toggles.nightTemp + "K" : "Off"
        active: Toggles.nightLight
        onClicked: Toggles.toggleNightLight()
    }
    QuickToggle {
        Layout.fillWidth: true
        icon: "sports_esports"
        label: "Game mode"
        sublabel: Toggles.gameMode ? "Effects off" : "Off"
        active: Toggles.gameMode
        onClicked: Toggles.toggleGameMode()
    }
    QuickToggle {
        Layout.fillWidth: true
        icon: "monitoring"
        label: "Bar stats"
        sublabel: Toggles.showStats ? "CPU · RAM · GPU" : "Hidden"
        active: Toggles.showStats
        onClicked: Toggles.toggleStats()
    }
    QuickToggle {
        Layout.fillWidth: true
        visible: AudioFx.eqAvailable
        icon: "graphic_eq"
        label: "AutoEq"
        sublabel: AudioFx.eq ? AudioFx.eqProfile : "Off"
        active: AudioFx.eq
        more: true
        onClicked: AudioFx.toggleEq()
        onMoreClicked: Panels.toggle("audioFx")
    }
    QuickToggle {
        Layout.fillWidth: true
        icon: "noise_control_off"
        label: "Mic denoise"
        sublabel: AudioFx.nc ? "RNNoise · " + Math.round(AudioFx.strength) + "%" : "Off"
        active: AudioFx.nc
        more: true
        onClicked: AudioFx.toggleNc()
        onMoreClicked: Panels.toggle("audioFx")
    }
}
