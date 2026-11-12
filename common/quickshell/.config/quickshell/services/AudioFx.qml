pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio effects state + actions; the work is done by scripts/audiofx.
//   eq  — headphone AutoEq (PipeWire param_eq smart filter), only on machines whose
//         ~/.config/mocha-shell/host.json has audio.autoeq
//   nc  — mic noise suppression (RNNoise smart filter on the mic)
Singleton {
    id: root

    readonly property string script: Quickshell.env("HOME") + "/.config/quickshell/scripts/audiofx"

    property bool eq: false
    property bool nc: false
    property bool eqAvailable: false
    property string eqProfile: "AutoEq"
    property string eqDevice: ""
    property real strength: 100     // %
    property real threshold: 50     // %
    property real grace: 200        // ms
    property real retro: 0          // ms
    property bool busy: false
    readonly property bool mutingMics: muter.running

    // emitted after the F22 "mute every mic" action with the resulting state
    signal micsToggled(bool muted)

    function refresh() {
        status.running = true;
    }
    function toggleEq() {
        eq = !eq;                       // optimistic; status confirms
        run(["eq", eq ? "on" : "off"]);
    }
    function toggleNc() {
        nc = !nc;
        run(["nc", nc ? "on" : "off"]);
    }
    // dials: update locally right away, push to PipeWire debounced
    function set(key, value) {
        root[key] = value;
        pending[key] = value;
        pushTimer.restart();
    }
    function muteAllMics() {
        muter.running = true;
    }

    property var pending: ({})

    function run(args) {
        busy = true;
        const p = runner.createObject(root, {
            command: [script].concat(args)
        });
        p.exited.connect(() => {
            p.destroy();
            busy = false;
            refresh();
        });
        p.running = true;
    }

    Component {
        id: runner
        Process {}
    }

    Timer {
        id: pushTimer
        interval: 120
        onTriggered: {
            for (const k in root.pending)
                Quickshell.execDetached([root.script, "set", k, String(Math.round(root.pending[k]))]);
            root.pending = {};
        }
    }

    Process {
        id: status
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const s = JSON.parse(text);
                    root.eq = s.eq;
                    root.nc = s.nc;
                    root.eqAvailable = s.eqAvailable;
                    root.eqProfile = s.eqProfile;
                    root.eqDevice = s.eqDevice;
                    if (!pushTimer.running) {
                        root.strength = s.strength;
                        root.threshold = s.threshold;
                        root.grace = s.grace;
                        root.retro = s.retro;
                    }
                } catch (e) {}
            }
        }
    }

    Process {
        id: muter
        command: [root.script, "mute-all", "toggle"]
        stdout: StdioCollector {
            onStreamFinished: {
                const muted = text.trim() === "muted";
                Quickshell.execDetached(["pw-play", "--volume=0.6", Quickshell.env("HOME") + "/.local/share/mocha-shell/sounds/" + (muted ? "mic-mute.wav" : "mic-unmute.wav")]);
                root.micsToggled(muted);
            }
        }
    }

    Component.onCompleted: refresh()
}
