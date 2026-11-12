import QtQuick
import qs.core

// Material Symbols Rounded glyph. `fill` animates between outlined (0) and filled (1).
Text {
    id: root

    property string icon: ""
    property real size: Theme.iconSize
    property real fill: 0
    property int weight: 400

    text: icon
    color: Theme.text
    font.family: Theme.fontIcon
    font.pixelSize: size
    font.variableAxes: ({
            "FILL": fill,
            "wght": weight,
            "GRAD": 0,
            "opsz": Math.max(20, Math.min(48, size))
        })
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    textFormat: Text.PlainText

    Behavior on fill {
        Anim {
            duration: Theme.animFast
        }
    }
    Behavior on color {
        CAnim {}
    }
}
