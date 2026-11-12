pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Which overlay is open. Only one interactive panel at a time.
Singleton {
    id: root

    property bool launcher: false
    property string launcherQuery: ""
    property bool controlCenter: false
    property bool session: false
    property bool overview: false
    property bool switcher: false
    property bool capture: false
    property bool calendar: false
    property bool audioFx: false
    property bool bluetooth: false
    property bool soundPicker: false     // control center: device list expanded

    readonly property bool anyOpen: launcher || controlCenter || session || overview || switcher || capture || calendar || audioFx || bluetooth

    // Screen the user is working on — overlays open there.
    readonly property var activeScreen: {
        const name = Hyprland.focusedMonitor?.name;
        const screens = Quickshell.screens;
        for (let i = 0; i < screens.length; i++)
            if (screens[i].name === name)
                return screens[i];
        return screens.length > 0 ? screens[0] : null;
    }

    function closeAll() {
        launcher = false;
        controlCenter = false;
        session = false;
        overview = false;
        switcher = false;
        capture = false;
        calendar = false;
        audioFx = false;
        bluetooth = false;
    }

    function toggle(name) {
        const next = !root[name];
        closeAll();
        root[name] = next;
    }

    function openLauncher(prefix) {
        const wasOpen = launcher && launcherQuery === prefix;
        closeAll();
        if (wasOpen)
            return;
        launcherQuery = prefix;
        launcher = true;
    }
}
