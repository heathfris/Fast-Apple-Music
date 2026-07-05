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
        id: iconText
        anchors.centerIn: parent
        text: root.iconText
        color: root.iconColor
        font.pixelSize: 16
        opacity: root.spinning ? 0.35 : 1.0

        // 处理中：脉冲呼吸动画（实心圆旋转不可见，改用透明度脉冲）
        SequentialAnimation on opacity {
            running: root.spinning
            loops: Animation.Infinite
            NumberAnimation { from: 0.35; to: 1.0; duration: 600 }
            NumberAnimation { from: 1.0; to: 0.35; duration: 600 }
        }
    }
}
