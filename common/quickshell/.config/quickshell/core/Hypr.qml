pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland

// Hyprland helpers. Hyprland 0.57 uses the Lua config, so dispatches are
// Lua expressions (hl.dsp.*) rather than the legacy "workspace 3" strings.
Singleton {
    id: root

    function lua(s) {
        return JSON.stringify(String(s));
    }
    function dispatch(expr) {
        Hyprland.dispatch(expr);
    }
    function focusWorkspace(id) {
        dispatch(`hl.dsp.focus({ workspace = ${id} })`);
    }
    function focusWorkspaceRelative(delta) {
        dispatch(`hl.dsp.focus({ workspace = ${lua(delta > 0 ? "e+1" : "e-1")} })`);
    }
    function addr(a) {
        a = String(a);
        return a.startsWith("0x") ? a : "0x" + a;
    }
    function focusWindow(address) {
        dispatch(`hl.dsp.focus({ window = ${lua("address:" + addr(address))} })`);
    }
    function closeWindow(address) {
        dispatch(`hl.dsp.window.close({ window = ${lua("address:" + addr(address))} })`);
    }
    function moveWindowToWorkspace(address, ws) {
        dispatch(`hl.dsp.window.move({ window = ${lua("address:" + addr(address))}, workspace = ${ws}, follow = false })`);
    }
    function exec(cmd) {
        dispatch(`hl.dsp.exec_cmd(${lua(cmd)})`);
    }
    function dpms(on) {
        dispatch(`hl.dsp.dpms({ action = ${lua(on ? "on" : "off")} })`);
    }
    function exit() {
        dispatch("hl.dsp.exit()");
    }
    // Live config change (used by game mode). Takes a Lua table literal.
    function config(tableLiteral) {
        dispatch(`function() hl.config(${tableLiteral}) end`);
    }
    function reload() {
        dispatch("hl.dsp.reload_config()");
    }

    // Toplevels sorted by most recently focused (for alt-tab).
    function windowsByFocus() {
        const list = Hyprland.toplevels.values.filter(t => !t.lastIpcObject || t.lastIpcObject.mapped !== false);
        return list.sort((a, b) => (a.lastIpcObject?.focusHistoryID ?? 999) - (b.lastIpcObject?.focusHistoryID ?? 999));
    }

    // lastIpcObject (positions, focus history) only updates on refresh; keep it fresh.
    Connections {
        target: Hyprland
        function onActiveToplevelChanged() {
            refreshTimer.restart();
        }
        function onFocusedWorkspaceChanged() {
            refreshTimer.restart();
        }
    }
    Timer {
        id: refreshTimer
        interval: 150
        onTriggered: Hyprland.refreshToplevels()
    }

    function iconFor(appClass) {
        if (!appClass)
            return Quickshell.iconPath("application-x-executable");
        const entry = DesktopEntries.heuristicLookup(appClass);
        const name = entry?.icon || appClass.toLowerCase();
        return Quickshell.iconPath(name, "application-x-executable");
    }
}
