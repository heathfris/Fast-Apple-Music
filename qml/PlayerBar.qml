import QtQuick
import QtQuick.Controls

Rectangle {
    id: playerBar

    height: 56
    color: "#2C2C2E"

    // 绑定到 bridge 属性（通过 notify 信号自动刷新）
    property string currentTitle: (typeof bridge !== "undefined") ? bridge.currentTitle : ""
    property bool isPlaying: (typeof bridge !== "undefined") ? bridge.isPlaying : false
    property int currentPosition: (typeof bridge !== "undefined") ? bridge.currentPosition : 0
    property int totalDuration: (typeof bridge !== "undefined") ? bridge.totalDuration : 0

    // 播放控件区 — 左 15%、右 10% 留白
    Item {
        id: controlsContainer
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.12
        anchors.right: parent.right
        anchors.rightMargin: parent.width * 0.10
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height

        Row {
            anchors.centerIn: parent
            spacing: 12

            // 播放/暂停 — 缩小至 34×34
            Rectangle {
                width: 34; height: 34; radius: 17
                color: "#FA2D48"
                anchors.verticalCenter: parent.verticalCenter

                // 播放三角
                Canvas {
                    anchors.centerIn: parent
                    width: 14; height: 14
                    visible: !playerBar.isPlaying
                    onPaint: {
                        var ctx = getContext("2d");
                        ctx.clearRect(0, 0, width, height);
                        ctx.fillStyle = "#FFFFFF";
                        ctx.beginPath();
                        ctx.moveTo(3, 2);
                        ctx.lineTo(12, 7);
                        ctx.lineTo(3, 12);
                        ctx.closePath();
                        ctx.fill();
                    }
                }

                // 暂停双竖条
                Item {
                    anchors.centerIn: parent
                    width: 12; height: 14
                    visible: playerBar.isPlaying
                    Rectangle {
                        width: 4; height: parent.height
                        anchors.left: parent.left
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#FFFFFF"; radius: 2
                    }
                    Rectangle {
                        width: 4; height: parent.height
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        color: "#FFFFFF"; radius: 2
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (typeof bridge !== "undefined") bridge.toggle_play();
                    }
                }
            }

            // 歌名
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: playerBar.currentTitle || "未在播放"
                color: playerBar.currentTitle ? "#FFFFFF" : "#8E8E93"
                font.pixelSize: 13
                font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
                elide: Text.ElideRight
                width: 160
            }

            // 进度条 — 自适应剩余宽度
            Slider {
                id: progressSlider
                anchors.verticalCenter: parent.verticalCenter
                width: Math.max(120, controlsContainer.width - 480)
                from: 0
                to: playerBar.totalDuration || 1
                value: playerBar.currentPosition
                onMoved: {
                    if (typeof bridge !== "undefined") bridge.seek(value);
                }

                background: Rectangle {
                    x: progressSlider.leftPadding
                    y: progressSlider.topPadding + progressSlider.availableHeight / 2 - 2
                    implicitWidth: 200; implicitHeight: 4
                    width: progressSlider.availableWidth; height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.15)

                    Rectangle {
                        width: progressSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#FA2D48"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: progressSlider.leftPadding + progressSlider.visualPosition * (progressSlider.availableWidth - width)
                    y: progressSlider.topPadding + progressSlider.availableHeight / 2 - height / 2
                    implicitWidth: 12; implicitHeight: 12
                    radius: 6
                    color: "#FA2D48"
                }
            }

            // 时间
            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: _formatTime(playerBar.currentPosition) + " / " + _formatTime(playerBar.totalDuration)
                color: "#8E8E93"
                font.pixelSize: 11
                width: 70
            }

            // 音量
            Slider {
                id: volumeSlider
                anchors.verticalCenter: parent.verticalCenter
                width: 100
                from: 0.0
                to: 1.0
                value: (typeof bridge !== "undefined") ? bridge.get_volume() : 0.8
                onMoved: {
                    if (typeof bridge !== "undefined") bridge.set_volume(value);
                }

                background: Rectangle {
                    x: volumeSlider.leftPadding
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - 2
                    implicitWidth: 100; implicitHeight: 4
                    width: volumeSlider.availableWidth; height: 4
                    radius: 2
                    color: Qt.rgba(1, 1, 1, 0.15)

                    Rectangle {
                        width: volumeSlider.visualPosition * parent.width
                        height: parent.height
                        color: "#FA2D48"
                        radius: 2
                    }
                }

                handle: Rectangle {
                    x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
                    y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
                    implicitWidth: 12; implicitHeight: 12
                    radius: 6
                    color: "#FA2D48"
                }
            }
        }
    }

    function _formatTime(ms) {
        var s = Math.floor(ms / 1000);
        var m = Math.floor(s / 60);
        s = s % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
