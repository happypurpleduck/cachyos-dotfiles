pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Hokum owns notifications; the shell only mirrors and toggles Do Not Disturb.
Singleton {
    id: root

    property bool dnd: false

    function toggleDnd() {
        Quickshell.execDetached(["hokum", "dnd", "toggle"]);
    }
    function openSettings() {
        Quickshell.execDetached(["hokum"]);
    }

    Process {
        id: watch
        running: true
        command: ["hokum", "dnd", "--json", "--watch"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.dnd = JSON.parse(line).dnd === true;
                } catch (e) {}
            }
        }
        onExited: restart.start()
    }
    Timer {
        id: restart
        interval: 5000
        onTriggered: watch.running = true
    }
}
