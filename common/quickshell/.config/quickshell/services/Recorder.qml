pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Screen recording with gpu-screen-recorder (NVENC on NVIDIA).
Singleton {
    id: root

    readonly property bool recording: proc.running
    property int elapsed: 0
    property string file: ""
    property string mode: ""

    function fmtElapsed() {
        const m = Math.floor(elapsed / 60), s = elapsed % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }

    // what: "screen" | "region";  audio: include desktop audio
    function start(what, audio) {
        if (recording)
            return;
        mode = what;
        const dir = Theme.home + "/Videos/Recordings";
        const stamp = Qt.formatDateTime(new Date(), "yyyy-MM-dd_HH-mm-ss");
        file = `${dir}/recording_${stamp}.mp4`;
        const monitor = Panels.activeScreen?.name ?? "screen";
        const a = audio ? "-a default_output" : "";
        const target = what === "region" ? `-w region -region "$(slurp -d -f '%wx%h+%x+%y')" ` : `-w ${monitor} `;
        proc.command = ["sh", "-c", `mkdir -p "${dir}" && exec gpu-screen-recorder ${target} -f 60 -k h264 -q very_high -c mp4 ${a} -o "${file}"`];
        elapsed = 0;
        proc.running = true;
    }
    function stop() {
        if (recording)
            proc.signal(2);  // SIGINT finalises the file
    }
    function toggle(what) {
        recording ? stop() : start(what || "screen", true);
    }

    Process {
        id: proc
        onExited: (code, status) => {
            if (root.file !== "")
                Quickshell.execDetached(["sh", "-c", `[ -s "$1" ] && notify-send -a "Recorder" -i video-x-generic "Recording saved" "$1"`, "_", root.file]);
        }
    }
    Timer {
        running: root.recording
        interval: 1000
        repeat: true
        onTriggered: root.elapsed++
    }
}
