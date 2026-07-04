import QtQuick
import QtQuick.Controls

Rectangle {
    id: playerBar

    height: 56
    color: "#2C2C2E"

    property string currentTitle: ""
    property bool isPlaying: false
    property int currentPosition: 0
    property int totalDuration: 0

    Row {
        anchors.centerIn: parent
        spacing: 16

        // 播放/暂停
        Rectangle {
            width: 36; height: 36; radius: 18
            color: "#FA2D48"
            anchors.verticalCenter: parent.verticalCenter

            Text {
                anchors.centerIn: parent
                text: playerBar.isPlaying ? "⏸" : "▶"
                color: "#FFFFFF"
                font.pixelSize: 14
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
            width: 200
        }

        // 进度条
        Slider {
            id: progressSlider
            anchors.verticalCenter: parent.verticalCenter
            width: 200
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
        }
    }

    function _formatTime(ms) {
        var s = Math.floor(ms / 1000);
        var m = Math.floor(s / 60);
        s = s % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }
}
