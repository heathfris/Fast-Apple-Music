import QtQuick
import QtQuick.Controls

Rectangle {
    id: sidebar

    signal pageChanged(int page)

    property int currentPage: 0

    width: 140
    color: Qt.rgba(44/255, 44/255, 46/255, 0.85)

    Column {
        anchors.fill: parent
        anchors.topMargin: 60
        spacing: 4

        // 文件列表 — 默认首页，放在最上面
        NavButton {
            text: "文件列表"
            isActive: sidebar.currentPage === 0
            onClicked: { sidebar.currentPage = 0; sidebar.pageChanged(0) }
        }

        Rectangle {
            width: parent.width - 20; height: 1
            color: Qt.rgba(1, 1, 1, 0.1)
            anchors.horizontalCenter: parent.horizontalCenter
        }

        NavButton {
            text: "输出目录"
            isActive: sidebar.currentPage === 1
            onClicked: { sidebar.currentPage = 1; sidebar.pageChanged(1) }
        }
        NavButton {
            text: "历史记录"
            isActive: sidebar.currentPage === 2
            onClicked: { sidebar.currentPage = 2; sidebar.pageChanged(2) }
        }
    }

    Text {
        anchors.bottom: parent.bottom; anchors.bottomMargin: 20
        anchors.horizontalCenter: parent.horizontalCenter
        text: "v1.0.0"; color: "#555555"; font.pixelSize: 11
    }

    component NavButton: Rectangle {
        property string text: ""
        property bool isActive: false
        signal clicked()

        width: sidebar.width - 16; height: 36; radius: 8
        color: isActive ? Qt.rgba(1,1,1,0.08) : "transparent"
        anchors.horizontalCenter: parent.horizontalCenter

        Text {
            anchors.centerIn: parent
            text: parent.text
            color: parent.isActive ? "#FFFFFF" : "#98989D"
            font.pixelSize: 13
            font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
        }

        MouseArea {
            anchors.fill: parent; hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: parent.clicked()
        }
    }
}
