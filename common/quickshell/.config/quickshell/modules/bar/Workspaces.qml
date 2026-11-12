import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import qs.core
import qs.components

// Workspace dots for this bar's monitor: active = accent pill, occupied = text dot,
// empty = faint dot. Only workspaces that belong to this monitor are shown, so with
// two screens the right bar shows 1–9 and the left bar shows 10.
Item {
    id: root

    property string screenName: ""
    readonly property var monitor: Hyprland.monitors.values.find(m => m.name === screenName) ?? Hyprland.focusedMonitor
    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property var all: Hyprland.workspaces.values.filter(ws => ws.id > 0)

    readonly property var occupied: {
        const o = {};
        for (const ws of all)
            if ((ws.toplevels?.values?.length ?? 0) > 0)
                o[ws.id] = true;
        return o;
    }
    readonly property var urgent: {
        const u = {};
        for (const ws of all)
            if (ws.urgent)
                u[ws.id] = true;
        return u;
    }
    // workspaces that currently live on another monitor
    readonly property var elsewhere: {
        const e = {};
        for (const ws of all)
            if (ws.monitor && ws.monitor.name !== screenName)
                e[ws.id] = true;
        return e;
    }
    // This monitor hosts the "main" range if workspace 1 is here (or doesn't exist elsewhere).
    readonly property bool hostsMain: !elsewhere[1]
    readonly property var ids: {
        const set = {};
        for (const ws of all)
            if (ws.monitor?.name === screenName)
                set[ws.id] = true;
        set[activeId] = true;
        if (hostsMain) {
            let max = 5;
            for (const k in set)
                if (Number(k) < 10)
                    max = Math.max(max, Number(k));
            for (let i = 1; i <= max; i++)
                if (!elsewhere[i])
                    set[i] = true;
        }
        return Object.keys(set).map(Number).sort((a, b) => a - b);
    }

    implicitWidth: row.implicitWidth + 8
    implicitHeight: 28

    Row {
        id: row
        anchors.centerIn: parent
        spacing: 2

        Repeater {
            model: root.ids

            Item {
                id: cell
                required property int modelData
                readonly property int wsId: modelData
                readonly property bool active: wsId === root.activeId
                readonly property bool busy: root.occupied[wsId] === true
                readonly property bool alert: root.urgent[wsId] === true

                width: active ? 30 : 18
                height: 28
                Behavior on width {
                    Anim {}
                }

                Rectangle {
                    anchors.centerIn: parent
                    width: cell.active ? 22 : (hover.containsMouse ? 10 : 7)
                    height: cell.active ? 8 : width
                    radius: height / 2
                    color: cell.alert ? Theme.red : cell.active ? Theme.accent : cell.busy ? Theme.subtext1 : Theme.surface2
                    Behavior on width {
                        Anim {}
                    }
                    Behavior on height {
                        Anim {}
                    }
                    Behavior on color {
                        CAnim {}
                    }
                }

                MouseArea {
                    id: hover
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hypr.focusWorkspace(cell.wsId)
                }
            }
        }
    }

    WheelHandler {
        onWheel: e => Hypr.focusWorkspaceRelative(e.angleDelta.y > 0 ? -1 : 1)
    }
}
