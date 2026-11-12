pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Bluetooth

// Network + Bluetooth summary for the bar and control center.
Singleton {
    id: root

    readonly property var devices: Networking.devices.values
    readonly property var wired: devices.find(d => d.type === DeviceType.Wired && d.connected) ?? null
    readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var wifiNetwork: wifiDevice ? (wifiDevice.networks.values.find(n => n.connected) ?? null) : null
    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool hasWifi: wifiDevice !== null
    readonly property bool online: wired !== null || wifiNetwork !== null

    readonly property string icon: {
        if (wired)
            return "lan";
        if (wifiNetwork) {
            const s = wifiNetwork.signalStrength;
            return s > 0.75 ? "network_wifi" : s > 0.5 ? "network_wifi_3_bar" : s > 0.25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
        }
        if (hasWifi && !wifiEnabled)
            return "wifi_off";
        return "signal_disconnected";
    }
    readonly property string label: wired ? "Ethernet" : wifiNetwork ? wifiNetwork.name : (hasWifi && !wifiEnabled ? "Wi-Fi off" : "Offline")
    readonly property string sublabel: wired ? (wired.name || "Connected") : wifiNetwork ? Math.round(wifiNetwork.signalStrength * 100) + "% signal" : (hasWifi ? "Not connected" : "No network")

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    // ── Bluetooth ──
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btAvailable: adapter !== null
    readonly property bool btEnabled: adapter?.enabled ?? false
    readonly property var btConnected: (adapter?.devices.values ?? []).filter(d => d.connected)
    readonly property string btIcon: !btEnabled ? "bluetooth_disabled" : btConnected.length > 0 ? "bluetooth_connected" : "bluetooth"
    readonly property string btLabel: !btAvailable ? "No adapter" : !btEnabled ? "Off" : btConnected.length === 1 ? btConnected[0].name : btConnected.length > 1 ? btConnected.length + " devices" : "On"

    function toggleBluetooth() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }
}
