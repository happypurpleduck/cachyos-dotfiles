pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: !!(sink && sink.ready && sink.audio)

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property real micVolume: source?.audio?.volume ?? 0
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property string sinkName: sink ? nodeLabel(sink) : "No output"
    readonly property string sourceName: source ? nodeLabel(source) : "No input"

    readonly property string icon: muted || volume <= 0.001 ? "volume_off" : volume < 0.34 ? "volume_mute" : volume < 0.67 ? "volume_down" : "volume_up"
    readonly property string micIcon: micMuted ? "mic_off" : "mic"

    // Real devices for the picker. Our own effect nodes (Chu 2 AutoEq, mic RNNoise)
    // are smart filters that attach to a device by themselves, so they're hidden.
    function isEffect(n) {
        const name = n.name || "";
        return name.startsWith("effect_") || name.startsWith("mic_rnnoise") || name.startsWith("capture.") || name.startsWith("mocha-");
    }
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio && !isEffect(n))
    readonly property var sources: Pipewire.nodes.values.filter(n => !n.isSink && !n.isStream && n.audio && !isEffect(n))

    // ~/.config/mocha-shell/host.json (dotfiles: hosts/<hostname>) — this machine's hardware
    FileView {
        id: hostFile
        path: Quickshell.env("HOME") + "/.config/mocha-shell/host.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.hostLabels = JSON.parse(text()).audio?.labels ?? [];
            } catch (e) {
                root.hostLabels = [];
            }
        }
        onLoadFailed: root.hostLabels = []
    }
    property var hostLabels: []

    // Friendly device names: "AD104 High Definition Audio Controller Digital Stereo
    // (HDMI)" → "Monitor (HDMI / DP)", the motherboard codec → "Motherboard line out", …
    function nodeLabel(n) {
        if (!n)
            return "";
        const name = n.name || "";
        const desc = n.description || n.nickname || name;
        // per-machine names first (host.json audio.labels: {match: regex, sink, source})
        for (const l of hostLabels) {
            if (new RegExp(l.match).test(name)) {
                const label = n.isSink ? l.sink : l.source;
                if (label)
                    return label;
            }
        }
        if (name.includes("hdmi"))
            return "Monitor (HDMI / DP)";
        return desc.replace(/ (Analog|Digital) Stereo.*$/, "").replace(/ Mono( Fallback)?$/, "").replace(/ Pro( Audio)?$/, "");
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }

    function setVolume(v) {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }
    function toggleMute() {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }
    function setMicVolume(v) {
        if (source?.audio) {
            source.audio.muted = false;
            source.audio.volume = Math.max(0, Math.min(1, v));
        }
    }
    function toggleMicMute() {
        if (source?.audio)
            source.audio.muted = !source.audio.muted;
    }
    function setDefaultSink(node) {
        Pipewire.preferredDefaultAudioSink = node;
    }
    function setDefaultSource(node) {
        Pipewire.preferredDefaultAudioSource = node;
    }
}
