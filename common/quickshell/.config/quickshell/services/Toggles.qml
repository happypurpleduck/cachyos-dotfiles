pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core

// Small system toggles: caffeine (idle inhibit), night light, game mode, bar stats.
Singleton {
    id: root

    property bool caffeine: false
    property bool gameMode: false
    readonly property bool nightLight: sunset.running
    property int nightTemp: 4500
    // System stats in the top bar; remembered across restarts.
    readonly property bool showStats: prefs.showStats

    function toggleStats() {
        prefs.showStats = !prefs.showStats;
        prefsFile.writeAdapter();
    }

    function toggleCaffeine() {
        caffeine = !caffeine;
    }

    function toggleNightLight() {
        sunset.running = !sunset.running;
    }

    // Game mode: no animations, blur, shadows or gaps; restored by reloading the config.
    function toggleGameMode() {
        gameMode = !gameMode;
        if (gameMode)
            Hypr.config("{ animations = { enabled = false }, decoration = { blur = { enabled = false }, shadow = { enabled = false }, rounding = 0 }, general = { gaps_in = 0, gaps_out = 0, border_size = 1 } }");
        else
            Hypr.reload();
    }

    FileView {
        id: prefsFile
        path: Theme.stateDir + "/toggles.json"
        printErrors: false
        JsonAdapter {
            id: prefs
            property bool showStats: true
        }
    }

    Process {
        id: sunset
        command: ["hyprsunset", "-t", String(root.nightTemp)]
    }
}
