import QtQuick

Rectangle {
    id: root

    property real progress: 0.0
    property int ringSize: 24
    property color ringColor: "#007AFF"

    width: ringSize + 4
    height: ringSize + 4
    color: "transparent"

    Canvas {
        id: canvas
        anchors.fill: parent
        onPaint: {
            var ctx = getContext("2d");
            var cx = width / 2;
            var cy = height / 2;
            var r = root.ringSize / 2 - 2;
            var startAngle = -Math.PI / 2;
            var endAngle = startAngle + (2 * Math.PI * root.progress);

            ctx.clearRect(0, 0, width, height);

            // 背景圆环
            ctx.beginPath();
            ctx.arc(cx, cy, r, 0, 2 * Math.PI);
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15);
            ctx.lineWidth = 3;
            ctx.stroke();

            // 进度弧
            ctx.beginPath();
            ctx.arc(cx, cy, r, startAngle, endAngle);
            ctx.strokeStyle = root.ringColor;
            ctx.lineWidth = 3;
            ctx.lineCap = "round";
            ctx.stroke();
        }
    }
}
