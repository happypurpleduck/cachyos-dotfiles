// Mocha greeter — login screen for greetd, sharing the lock screen's visuals.
// Installed to /etc/greetd/mocha-greeter by scripts/install-greeter and run as:
//   cage -s -- qs -p /etc/greetd/mocha-greeter
//@ pragma Env QS_NO_RELOAD_POPUP=1

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Greetd
import qs.core
import qs.modules.lock

ShellRoot {
    id: root

    property string pending: ""
    property bool busy: false
    property string message: ""
    property bool isError: false

    FileView {
        id: cfgFile
        path: Quickshell.shellPath("greeter.json")
        blockLoading: true
        JsonAdapter {
            id: cfg
            property string user: ""
            property string face: ""
            property var session: ["start-hyprland"]
        }
    }

    function login(password) {
        if (busy || !cfg.user)
            return;
        busy = true;
        message = "";
        isError = false;
        pending = password;
        Greetd.createSession(cfg.user);
    }

    Connections {
        target: Greetd
        function onAuthMessage(message, error, responseRequired, echoResponse) {
            if (responseRequired) {
                Greetd.respond(root.pending);
                root.pending = "";
            } else if (message) {
                root.message = message;
                root.isError = error;
            }
        }
        function onAuthFailure(message) {
            root.busy = false;
            root.message = "Wrong password";
            root.isError = true;
            content.clear();
            content.shake();
            content.focusField();
        }
        function onReadyToLaunch() {
            root.message = "Starting session…";
            root.isError = false;
            Greetd.launch(cfg.session, [], true);
        }
        function onError(error) {
            root.busy = false;
            root.message = error;
            root.isError = true;
            Greetd.cancelSession();
        }
    }

    // cage shows a single fullscreen toplevel
    FloatingWindow {
        visible: true
        color: Theme.crust

        LockContent {
            id: content
            anchors.fill: parent
            user: cfg.user
            facePath: cfg.face
            busy: root.busy
            message: root.message
            messageIsError: root.isError
            reveal: 0
            Component.onCompleted: {
                reveal = 1;
                focusField();
            }
            Behavior on reveal {
                NumberAnimation {
                    duration: 600
                    easing.type: Easing.OutCubic
                }
            }
            onSubmitted: pw => root.login(pw)
            onPowerAction: a => Quickshell.execDetached(["systemctl", a])
        }
    }
}
