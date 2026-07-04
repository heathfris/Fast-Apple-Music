import QtQuick
import QtQuick.Controls
import QtQuick.Window

Window {
    id: mainWindow
    width: 960
    height: 640
    minimumWidth: 800
    minimumHeight: 500
    visible: true
    title: "Fast Apple Music"
    color: "#1A1A1A"

    // 标题栏
    Rectangle {
        id: titleBar
        width: parent.width
        height: 40
        color: "#1E1E1E"
        z: 10

        Text {
            anchors.centerIn: parent
            text: "🎵  Fast Apple Music"
            color: "#FFFFFF"
            font.pixelSize: 14
            font.bold: true
            font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
        }
    }

    // 主内容区 — 三栏布局
    Row {
        anchors.top: titleBar.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: playerBar.top
        spacing: 0

        Sidebar {
            id: sidebar
            height: parent.height
        }

        FileList {
            id: fileList
            width: parent.width - sidebar.width - metadataPanel.width
            height: parent.height
        }

        MetadataPanel {
            id: metadataPanel
            height: parent.height
        }
    }

    // 底部播放条
    PlayerBar {
        id: playerBar
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }
}
