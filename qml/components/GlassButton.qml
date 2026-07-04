import QtQuick
import QtQuick.Controls

Button {
    id: root

    property string btnText: ""
    property string btnIcon: ""
    property color accentColor: "#FA2D48"

    text: btnIcon ? (btnIcon + " " + btnText) : btnText

    contentItem: Text {
        text: root.text
        font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
        font.pixelSize: 13
        color: root.enabled ? "#FFFFFF" : "#666666"
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }

    background: Rectangle {
        implicitWidth: 100
        implicitHeight: 32
        radius: 8
        color: root.down ? Qt.darker(root.accentColor, 1.2)
               : root.hovered ? Qt.lighter(root.accentColor, 1.1)
               : root.accentColor
        opacity: 0.9

        Behavior on color { ColorAnimation { duration: 150 } }
    }
}
