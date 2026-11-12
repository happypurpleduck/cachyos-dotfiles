import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.core

// Full-screen transparent layer used by every popup. Handles open/close
// animation (`progress`), dimming, click-outside and Escape to dismiss.
PanelWindow {
    id: win

    property bool open: false
    property string name: "overlay"
    property real dim: 0
    property bool grabKeyboard: true
    property int duration: Theme.animNormal
    property real progress: open ? 1 : 0
    default property alias content: holder.data
    readonly property Item contentRoot: holder

    signal dismissed
    // keys arriving at the overlay (children with focus, e.g. text fields, see them first)
    signal keyPressed(var event)
    signal keyReleased(var event)

    Behavior on progress {
        Anim {
            duration: win.duration
            easing.bezierCurve: win.open ? Theme.curveDecel : Theme.curveStandard
        }
    }

    screen: Panels.activeScreen
    visible: open || progress > 0.001
    color: "transparent"
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "mocha-" + name
    WlrLayershell.keyboardFocus: open && grabKeyboard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

    Rectangle {
        anchors.fill: parent
        color: Theme.crust
        opacity: win.dim * win.progress
    }

    MouseArea {
        anchors.fill: parent
        enabled: win.open
        acceptedButtons: Qt.AllButtons
        onClicked: win.dismissed()
    }

    FocusScope {
        id: holder
        anchors.fill: parent
        focus: true
        Keys.onPressed: e => {
            win.keyPressed(e);
            if (!e.accepted && e.key === Qt.Key_Escape) {
                win.dismissed();
                e.accepted = true;
            }
        }
        Keys.onReleased: e => win.keyReleased(e)
    }

    onOpenChanged: if (open)
        holder.forceActiveFocus()
}
