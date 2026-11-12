pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property var players: Mpris.players.values
    property MprisPlayer manual: null
    // Prefer: the player the user picked → anything playing → first player.
    readonly property MprisPlayer active: {
        if (manual && players.indexOf(manual) >= 0)
            return manual;
        for (let i = 0; i < players.length; i++)
            if (players[i].isPlaying)
                return players[i];
        return players.length > 0 ? players[0] : null;
    }
    readonly property bool hasPlayer: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle || ""
    readonly property string artist: active?.trackArtist || ""
    readonly property string artUrl: active?.trackArtUrl || ""
    readonly property real length: active?.length ?? 0
    readonly property real position: active?.position ?? 0

    function toggle() {
        if (active?.canTogglePlaying)
            active.togglePlaying();
    }
    function next() {
        if (active?.canGoNext)
            active.next();
    }
    function previous() {
        if (active?.canGoPrevious)
            active.previous();
    }
    function seek(fraction) {
        if (active?.canSeek && length > 0)
            active.position = fraction * length;
    }
    function cycle() {
        if (players.length < 2)
            return;
        manual = players[(players.indexOf(active) + 1) % players.length];
    }
    function fmt(secs) {
        secs = Math.max(0, Math.floor(secs));
        const m = Math.floor(secs / 60), s = secs % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    // MPRIS position isn't pushed; poll while playing.
    Timer {
        running: root.playing
        interval: 1000
        repeat: true
        onTriggered: root.active?.positionChanged()
    }
}
