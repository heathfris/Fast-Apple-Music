import QtQuick

Rectangle {
    id: root
    property string text: ""
    property bool active: false
    signal clicked()

    width: txt.implicitWidth + 16
    height: 36
    color: "transparent"

    Text {
        id: txt
        anchors.centerIn: parent
        text: root.text
        color: root.active ? "#FFFFFF" : "#8E8E93"
        font.pixelSize: 13
        font.bold: root.active
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width; height: 2
        color: root.active ? "#FA2D48" : "transparent"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}
