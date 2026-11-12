pragma Singleton

import QtQuick
import Quickshell
import qs.core

// Screenshot / colour-picker entry points. Panels are closed first and the
// capture runs after a short delay so the overlay isn't in the shot.
Singleton {
    id: root

    function run(args) {
        Panels.closeAll();
        Quickshell.execDetached(["sh", "-c", `sleep 0.25; exec "${Theme.scripts}/capture" "$@"`, "_"].concat(args));
    }
    function region() {
        run(["region"]);
    }
    function window() {
        run(["window"]);
    }
    function screen() {
        run(["screen"]);
    }
    function pickColor() {
        run(["color"]);
    }
}
