pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Current keyboard layout, kept live from Hyprland's "activelayout" event.
// Layouts come from input.kb_layout in hyprland.lua (us,ara); Super+Space switches.
Singleton {
    id: root

    property string layout: "English (US)"
    readonly property string short: {
        const l = layout.toLowerCase();
        if (l.startsWith("arabic"))
            return "AR";
        if (l.startsWith("english"))
            return "EN";
        return layout.slice(0, 2).toUpperCase();
    }

    function next() {
        switcher.running = true;
    }

    Process {
        id: switcher
        command: ["hyprctl", "switchxkblayout", "all", "next"]
    }

    // initial value: the main keyboard's active keymap
    Process {
        running: true
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kbs = JSON.parse(text).keyboards;
                    const kb = kbs.find(k => k.main) ?? kbs[0];
                    if (kb)
                        root.layout = kb.active_keymap;
                } catch (e) {}
            }
        }
    }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout")
                return;
            // data = "<keyboard name>,<layout name>"
            const d = event.data;
            const name = d.slice(d.indexOf(",") + 1);
            if (name && name !== "error")
                root.layout = name;
        }
    }
}
