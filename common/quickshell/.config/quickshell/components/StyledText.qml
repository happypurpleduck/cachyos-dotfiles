import QtQuick
import qs.core

Text {
    color: Theme.text
    font.family: Theme.fontSans
    font.pixelSize: Theme.fontMd
    verticalAlignment: Text.AlignVCenter
    elide: Text.ElideRight
    textFormat: Text.PlainText

    Behavior on color {
        CAnim {}
    }
}
