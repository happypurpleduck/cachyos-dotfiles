pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness. Laptops: brightnessctl (backlight). Desktops: ddcutil (DDC/CI
// over the monitor cable). If neither works, `available` stays false and the UI hides.
Singleton {
    id: root

    property string backend: "none"        // "backlight" | "ddc" | "none"
    property real value: 0.5               // 0..1
    readonly property bool available: backend !== "none"
    property real pending: -1

    signal changedByUser

    function set(v) {
        v = Math.max(0.01, Math.min(1, v));
        value = v;
        pending = v;
        debounce.restart();
        changedByUser();
    }
    function step(delta) {
        set(value + delta);
    }

    Process {
        id: detect
        running: true
        command: ["sh", "-c", "if command -v brightnessctl >/dev/null && [ -n \"$(ls /sys/class/backlight 2>/dev/null)\" ]; then echo backlight; elif command -v ddcutil >/dev/null && ddcutil detect --brief 2>/dev/null | grep -q '^Display'; then echo ddc; else echo none; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.backend = text.trim() || "none";
                if (root.available)
                    reader.running = true;
            }
        }
    }

    Process {
        id: reader
        command: root.backend === "backlight" ? ["sh", "-c", "echo $(brightnessctl g) $(brightnessctl m)"] : ["sh", "-c", "ddcutil getvcp 10 --brief 2>/dev/null | awk '{print $4, $5}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split(/\s+/).map(Number);
                if (p.length === 2 && p[1] > 0)
                    root.value = p[0] / p[1];
            }
        }
    }

    Timer {
        id: debounce
        interval: root.backend === "ddc" ? 250 : 30
        onTriggered: {
            if (root.pending < 0)
                return;
            const pct = Math.round(root.pending * 100);
            root.pending = -1;
            if (root.backend === "backlight")
                Quickshell.execDetached(["brightnessctl", "-q", "set", pct + "%"]);
            else if (root.backend === "ddc")
                Quickshell.execDetached(["ddcutil", "setvcp", "10", String(pct), "--noverify"]);
        }
    }
}
