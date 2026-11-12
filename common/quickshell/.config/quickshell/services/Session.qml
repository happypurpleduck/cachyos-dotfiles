pragma Singleton

import QtQuick
import Quickshell
import qs.core

// Lock state + power actions, shared by the power menu, launcher and lock screen.
Singleton {
    id: root

    property bool locked: false

    function lock() {
        Panels.closeAll();
        locked = true;
    }
    function suspend() {
        lock();
        Quickshell.execDetached(["sh", "-c", "sleep 0.6; systemctl suspend"]);
    }
    function logout() {
        Hypr.exit();
    }
    function reboot() {
        Quickshell.execDetached(["systemctl", "reboot"]);
    }
    function poweroff() {
        Quickshell.execDetached(["systemctl", "poweroff"]);
    }

    readonly property string user: Quickshell.env("USER")
    readonly property string face: Theme.home + "/.face"
}
