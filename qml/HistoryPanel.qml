import QtQuick
import QtQuick.Controls
import "components"

Rectangle {
    id: panel
    color: "#1A1A1A"

    function refreshHistory() {
        historyText.text = (typeof bridge !== "undefined")
            ? bridge.get_history() : "";
    }

    Connections {
        target: bridge
        function onFilesChanged() { refreshHistory() }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 32
        spacing: 16

        Row {
            width: parent.width
            spacing: 12

            Text {
                text: "转换历史记录"
                color: "#FFFFFF"
                font.pixelSize: 20; font.bold: true
                font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
            }

            GlassButton {
                btnText: "刷新"
                accentColor: "#3A3A3C"
                onClicked: refreshHistory()
            }
        }

        Rectangle {
            width: parent.width; height: 1
            color: Qt.rgba(1, 1, 1, 0.08)
        }

        ScrollView {
            width: parent.width
            height: parent.height - 60
            clip: true

            TextArea {
                id: historyText
                width: parent.width
                color: "#CCCCCC"
                font.pixelSize: 12
                font.family: "Consolas, monospace"
                readOnly: true
                background: Rectangle { color: "transparent" }
                text: (typeof bridge !== "undefined") ? bridge.get_history() : ""
            }
        }
    }

    Component.onCompleted: {
        if (typeof bridge !== "undefined") {
            historyText.text = bridge.get_history();
        }
    }
}
