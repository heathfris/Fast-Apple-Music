import QtQuick

Rectangle {
    id: root

    property string iconText: "○"
    property color iconColor: "#8E8E93"
    property bool spinning: false

    width: 20
    height: 20
    radius: 10
    color: "transparent"

    Text {
        anchors.centerIn: parent
        text: root.spinning ? "◌" : root.iconText
        color: root.iconColor
        font.pixelSize: 16

        RotationAnimation on rotation {
            running: root.spinning
            from: 0; to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }
}
