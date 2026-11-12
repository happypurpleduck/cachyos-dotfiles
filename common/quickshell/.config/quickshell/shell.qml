//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_FLICKABLE_WHEEL_DECELERATION=10000

// Mocha shell — Catppuccin Mocha, accent follows the wallpaper.
// Control from keybinds/scripts with:  qs ipc call <target> <function> [args]
//   launcher toggle | open <prefix>      controlcenter toggle | calendar toggle
//   mic muteAll                          audiofx toggle | eq | nc      bluetooth toggle
//   session toggle                        lock lock
//   overview toggle                       switcher next | prev
//   capture menu | region | window | screen | color
//   record toggle | screen | region       theme accent <name|auto> | random | wallpaper <path>

import QtQuick
import Quickshell
import Quickshell.Io
import qs.core
import qs.services
import qs.modules.bar
import qs.modules.osd
import qs.modules.launcher
import qs.modules.controlcenter
import qs.modules.session
import qs.modules.lock
import qs.modules.overview
import qs.modules.polkit
import qs.modules.capture
import qs.modules.idle
import qs.modules.calendar
import qs.modules.audiofx
import qs.modules.bluetooth

ShellRoot {
    id: shell

    Bar {}
    Osd {}
    Launcher {}
    ControlCenter {}
    CalendarPopup {}
    AudioFxPopup {}
    BluetoothPopup {}
    PairingDialog {}
    PowerMenu {}
    CaptureMenu {}
    Overview {}
    Switcher {
        id: switcher
    }
    Lock {}
    PolkitDialog {}
    Idle {}

    // A monitor was plugged in (e.g. the KVM switched back): awww starts new
    // outputs blank, so re-apply the current wallpaper to every screen.
    Connections {
        target: Quickshell
        function onScreensChanged() {
            wallpaperRestore.restart();
        }
    }
    Timer {
        id: wallpaperRestore
        interval: 1500
        onTriggered: Theme.themeCmd(["restore"])
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void {
            Panels.openLauncher("");
        }
        function open(prefix: string): void {
            Panels.openLauncher(prefix);
        }
        function clipboard(): void {
            Panels.openLauncher(">");
        }
        function emoji(): void {
            Panels.openLauncher(":");
        }
        function wallpaper(): void {
            Panels.openLauncher("@");
        }
        function actions(): void {
            Panels.openLauncher("/");
        }
    }
    IpcHandler {
        target: "controlcenter"
        function toggle(): void {
            Panels.toggle("controlCenter");
        }
        // open with the output/input device list expanded
        function devices(): void {
            Panels.closeAll();
            Panels.controlCenter = true;
            Panels.soundPicker = true;
        }
    }
    IpcHandler {
        target: "calendar"
        function toggle(): void {
            Panels.toggle("calendar");
        }
    }
    IpcHandler {
        target: "bluetooth"
        function toggle(): void {
            Panels.toggle("bluetooth");
        }
    }
    IpcHandler {
        target: "mic"
        // F22: mute / unmute every microphone (popup + chime)
        function muteAll(): void {
            AudioFx.muteAllMics();
        }
    }
    IpcHandler {
        target: "audiofx"
        function toggle(): void {
            Panels.toggle("audioFx");
        }
        function eq(): void {
            AudioFx.toggleEq();
        }
        function nc(): void {
            AudioFx.toggleNc();
        }
    }
    IpcHandler {
        target: "session"
        function toggle(): void {
            Panels.toggle("session");
        }
    }
    IpcHandler {
        target: "lock"
        function lock(): void {
            Session.lock();
        }
        function isLocked(): bool {
            return Session.locked;
        }
    }
    IpcHandler {
        target: "overview"
        function toggle(): void {
            Panels.toggle("overview");
        }
    }
    IpcHandler {
        target: "switcher"
        function next(): void {
            switcher.step(1);
        }
        function prev(): void {
            switcher.step(-1);
        }
        function commit(): void {
            switcher.commit();
        }
    }
    IpcHandler {
        target: "capture"
        function menu(): void {
            Panels.toggle("capture");
        }
        function region(): void {
            Capture.region();
        }
        function window(): void {
            Capture.window();
        }
        function screen(): void {
            Capture.screen();
        }
        function color(): void {
            Capture.pickColor();
        }
    }
    IpcHandler {
        target: "record"
        function toggle(): void {
            Recorder.toggle("screen");
        }
        function screen(): void {
            Recorder.recording ? Recorder.stop() : Recorder.start("screen", true);
        }
        function region(): void {
            Recorder.recording ? Recorder.stop() : Recorder.start("region", true);
        }
    }
    IpcHandler {
        target: "theme"
        function accent(name: string): void {
            Theme.setAccent(name);
        }
        function random(): void {
            Theme.themeCmd(["random"]);
        }
        function wallpaper(path: string): void {
            Theme.setWallpaper(path);
        }
        function current(): string {
            return Theme.accentName;
        }
    }
    IpcHandler {
        target: "toggles"
        function caffeine(): void {
            Toggles.toggleCaffeine();
        }
        function gamemode(): void {
            Toggles.toggleGameMode();
        }
        function nightlight(): void {
            Toggles.toggleNightLight();
        }
        function dnd(): void {
            Notifs.toggleDnd();
        }
        function stats(): void {
            Toggles.toggleStats();
        }
    }
}
