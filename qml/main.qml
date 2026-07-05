import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: mainWindow
    width: 960; height: 640
    minimumWidth: 800; minimumHeight: 500
    visible: true
    title: "Fast Apple Music"
    color: "#1A1A1A"
    flags: Qt.FramelessWindowHint | Qt.Window

    property int currentPage: 0

    // 全局键盘焦点 — 空格键播放/暂停，不受按钮焦点干扰
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Space) {
                if (typeof bridge !== "undefined") bridge.toggle_play();
                event.accepted = true;
            }
        }
    }

    // 自定义标题栏
    Rectangle {
        id: titleBar
        width: parent.width; height: 40; color: "#1E1E1E"; z: 10

        MouseArea {
            anchors.fill: parent; anchors.rightMargin: 80
            property point lastPos: Qt.point(0, 0)
            onPressed: function(mouse) { lastPos = Qt.point(mouse.x, mouse.y) }
            onPositionChanged: function(mouse) {
                mainWindow.x += mouse.x - lastPos.x
                mainWindow.y += mouse.y - lastPos.y
            }
        }

        Text {
            anchors.left: parent.left; anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            text: "Fast Apple Music"; color: "#FFFFFF"
            font.pixelSize: 13; font.bold: true
        }

        Rectangle {
            anchors.right: closeBtn.left; anchors.rightMargin: 4
            anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 6
            color: minBtnMa.containsMouse ? Qt.rgba(1,1,1,0.1) : "transparent"
            Text { anchors.centerIn: parent; text: "─"; color: "#FFFFFF"; font.pixelSize: 14 }
            MouseArea {
                id: minBtnMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mainWindow.showMinimized()
            }
        }

        Rectangle {
            id: closeBtn
            anchors.right: parent.right; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter; width: 28; height: 28; radius: 6
            color: closeBtnMa.containsMouse ? "#FF3B30" : "transparent"
            Text { anchors.centerIn: parent; text: "✕"
                color: closeBtnMa.containsMouse ? "#FFFFFF" : "#CCCCCC"; font.pixelSize: 13 }
            MouseArea {
                id: closeBtnMa; anchors.fill: parent; hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: mainWindow.close()
            }
        }
    }

    // 主内容区
    Row {
        anchors.top: titleBar.bottom
        anchors.left: parent.left; anchors.right: parent.right
        anchors.bottom: playerBar.top

        Sidebar {
            id: sidebar; height: parent.height
            onPageChanged: function(page) { mainWindow.currentPage = page }
        }

        // 中间区域 — 三个面板按 visible 切换
        Item {
            id: centerArea
            width: parent.width - sidebar.width - rightPanel.width
            height: parent.height

            FileList {
                id: fileList; anchors.fill: parent
                visible: mainWindow.currentPage === 0
            }
            OutputDirPanel {
                id: outputDirPanel; anchors.fill: parent
                visible: mainWindow.currentPage === 1
            }
            HistoryPanel {
                id: historyPanel; anchors.fill: parent
                visible: mainWindow.currentPage === 2
            }
        }

        RightPanel { id: rightPanel; height: parent.height }
    }

    PlayerBar {
        id: playerBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left; anchors.right: parent.right
    }
}
