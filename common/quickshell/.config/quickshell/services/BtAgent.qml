pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Runs scripts/bt-agent (BlueZ pairing agent) and exposes the current request
// for the pairing dialog. Requests queue up if several arrive at once.
Singleton {
    id: root

    // {id, type: pin|passkey|confirm|authorize|display, device, passkey?, code?, entered?}
    property var request: null
    property var queue: []
    property bool ready: false

    function respond(ok, value) {
        if (!request)
            return;
        if (request.id > 0)
            agent.write(request.id + (ok ? " ok" : " cancel") + (ok && value !== undefined && value !== "" ? " " + value : "") + "\n");
        next();
    }
    function dismiss() {
        respond(false);
    }

    function next() {
        if (queue.length > 0) {
            request = queue[0];
            queue = queue.slice(1);
        } else {
            request = null;
        }
    }
    function handle(msg) {
        switch (msg.type) {
        case "ready":
            ready = true;
            return;
        case "error":
            ready = false;
            console.warn("bt-agent:", msg.message);
            return;
        case "cancel":
            // BlueZ gave up (timeout / device cancelled): drop everything shown
            queue = [];
            request = null;
            return;
        default:
            if (request === null)
                request = msg;
            else if (msg.type === "display" && request.type === "display")
                request = msg;          // passkey entry progress updates
            else
                queue = queue.concat([msg]);
        }
    }

    Process {
        id: agent
        running: true
        stdinEnabled: true
        command: [Quickshell.env("HOME") + "/.config/quickshell/scripts/bt-agent"]
        stdout: SplitParser {
            onRead: line => {
                try {
                    root.handle(JSON.parse(line));
                } catch (e) {}
            }
        }
        onExited: {
            root.ready = false;
            root.request = null;
            restart.start();
        }
    }
    Timer {
        id: restart
        interval: 3000
        onTriggered: agent.running = true
    }
}
