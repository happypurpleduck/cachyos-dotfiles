pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// CPU / RAM / NVIDIA GPU / disk / temperatures. Polls only while something
// that shows stats is visible (`refCount` > 0) to stay idle otherwise.
Singleton {
    id: root

    property int refCount: 0
    readonly property bool active: refCount > 0 || Toggles.showStats || Panels.controlCenter || Panels.session

    property real cpu: 0          // 0..1
    property real cpuTemp: 0      // °C
    property real memUsed: 0      // GiB
    property real memTotal: 0
    readonly property real mem: memTotal > 0 ? memUsed / memTotal : 0
    property real gpu: 0          // 0..1
    property real gpuTemp: 0
    property real vramUsed: 0     // GiB
    property real vramTotal: 0
    property string gpuName: ""
    property real diskUsed: 0     // GiB
    property real diskTotal: 0
    readonly property real disk: diskTotal > 0 ? diskUsed / diskTotal : 0
    property real uptime: 0       // seconds

    property var _lastCpu: null
    property string cpuTempPath: ""

    Timer {
        running: root.active
        interval: 2000
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            up.reload();
            if (root.cpuTempPath)
                temp.reload();
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const l = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = l[3] + (l[4] || 0);
            const total = l.reduce((a, b) => a + b, 0);
            if (root._lastCpu) {
                const dt = total - root._lastCpu.total, di = idle - root._lastCpu.idle;
                if (dt > 0)
                    root.cpu = Math.max(0, Math.min(1, 1 - di / dt));
            }
            root._lastCpu = {
                total,
                idle
            };
        }
    }
    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const kb = k => Number((t.match(new RegExp("^" + k + ":\\s+(\\d+)", "m")) || [0, 0])[1]);
            root.memTotal = kb("MemTotal") / 1048576;
            root.memUsed = (kb("MemTotal") - kb("MemAvailable")) / 1048576;
        }
    }
    FileView {
        id: up
        path: "/proc/uptime"
        onLoaded: root.uptime = Number(text().split(" ")[0])
    }
    FileView {
        id: temp
        path: root.cpuTempPath
        onLoaded: root.cpuTemp = Number(text().trim()) / 1000
    }

    Process {
        running: true
        command: ["sh", "-c", "for h in /sys/class/hwmon/hwmon*; do case $(cat $h/name) in k10temp|coretemp|zenpower|cpu_thermal) for t in $h/temp*_label; do case $(cat $t) in Tctl|Tdie|'Package id 0') echo ${t%_label}_input; exit;; esac; done; echo $h/temp1_input; exit;; esac; done"]
        stdout: StdioCollector {
            onStreamFinished: root.cpuTempPath = text.trim()
        }
    }

    // nvidia-smi in loop mode: one line every 2 s while active.
    Process {
        id: nvidia
        running: root.active
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,name", "--format=csv,noheader,nounits", "-l", "2"]
        stdout: SplitParser {
            onRead: line => {
                const p = line.split(",").map(s => s.trim());
                if (p.length < 5)
                    return;
                root.gpu = Number(p[0]) / 100;
                root.gpuTemp = Number(p[1]);
                root.vramUsed = Number(p[2]) / 1024;
                root.vramTotal = Number(p[3]) / 1024;
                root.gpuName = p[4].replace(/^NVIDIA\s+/, "").replace(/^GeForce\s+/, "");
            }
        }
    }

    Process {
        id: df
        command: ["df", "-B1", "--output=used,size", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const p = text.trim().split("\n").pop().trim().split(/\s+/).map(Number);
                root.diskUsed = p[0] / 1073741824;
                root.diskTotal = p[1] / 1073741824;
            }
        }
    }
    Timer {
        running: root.active
        interval: 60000
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
    }

    function fmtUptime() {
        const h = Math.floor(uptime / 3600), m = Math.floor(uptime % 3600 / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
}
