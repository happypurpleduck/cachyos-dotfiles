import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import qs.core
import qs.services

// Session lock (ext-session-lock) with PAM authentication.
Scope {
    id: root

    property string message: ""
    property bool messageIsError: false
    property bool busy: false
    signal failed

    PamContext {
        id: pam
        configDirectory: Quickshell.shellPath("pam")
        config: "password.conf"
        user: Session.user

        onPamMessage: {
            if (responseRequired && root.pendingPassword !== "") {
                respond(root.pendingPassword);
                root.pendingPassword = "";
            } else if (message) {
                root.message = message;
                root.messageIsError = messageIsError;
            }
        }
        onCompleted: result => {
            root.busy = false;
            if (result === PamResult.Success) {
                root.message = "";
                root.messageIsError = false;
                Session.locked = false;
            } else {
                root.message = result === PamResult.MaxTries ? "Too many attempts — wait a moment" : "Wrong password";
                root.messageIsError = true;
                root.failed();
            }
        }
        onError: err => {
            root.busy = false;
            root.message = "Authentication error";
            root.messageIsError = true;
            root.failed();
        }
    }
    property string pendingPassword: ""

    function tryUnlock(password) {
        if (busy)
            return;
        busy = true;
        message = "";
        messageIsError = false;
        pendingPassword = password;
        if (!pam.start()) {
            busy = false;
            message = "Could not start authentication";
            messageIsError = true;
        }
    }

    WlSessionLock {
        id: lock
        locked: Session.locked

        WlSessionLockSurface {
            id: surface
            color: Theme.crust

            LockContent {
                id: content
                anchors.fill: parent
                user: Session.user
                facePath: Session.face
                busy: root.busy
                message: root.message
                messageIsError: root.messageIsError
                reveal: 0
                keyboardLayout: Keyboard.short
                onLayoutClicked: Keyboard.next()
                Component.onCompleted: {
                    reveal = 1;
                    focusField();
                }
                Behavior on reveal {
                    NumberAnimation {
                        duration: Theme.animSlow
                        easing.type: Easing.OutCubic
                    }
                }
                onSubmitted: pw => root.tryUnlock(pw)
                onPowerAction: a => a === "suspend" ? Quickshell.execDetached(["systemctl", "suspend"]) : a === "reboot" ? Session.reboot() : Session.poweroff()

                Connections {
                    target: root
                    function onFailed() {
                        content.clear();
                        content.shake();
                        content.focusField();
                    }
                }
            }
        }
    }
}
