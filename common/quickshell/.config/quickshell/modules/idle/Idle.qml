import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core
import qs.services

// Idle policy: lock after 5 min, turn the monitors off after 7 min.
// No automatic suspend. Respects idle inhibitors (videos, fullscreen games)
// and the "Keep awake" toggle.
Scope {
    id: root

    readonly property int lockAfter: 5 * 60
    readonly property int screenOffAfter: 7 * 60

    IdleMonitor {
        timeout: root.lockAfter
        respectInhibitors: true
        enabled: !Toggles.caffeine
        onIsIdleChanged: if (isIdle)
            Session.lock()
    }

    IdleMonitor {
        timeout: root.screenOffAfter
        respectInhibitors: true
        enabled: !Toggles.caffeine
        onIsIdleChanged: Hypr.dpms(!isIdle)
    }
}
