import QtQuick
import QtQuick.Controls
import "components"

Rectangle {
    id: panel
    color: "#1A1A1A"

    Flickable {
        anchors.fill: parent
        anchors.margins: 32
        contentHeight: column.implicitHeight
        clip: true

        Column {
            id: column
            width: parent.width
            spacing: 24

            Text {
                text: "输出目录设置"
                color: "#FFFFFF"
                font.pixelSize: 20; font.bold: true
                font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
            }

            // 音频输出目录
            Column { spacing: 8; width: parent.width
                Text {
                    text: "音频输出目录"
                    color: "#8E8E93"; font.pixelSize: 12
                    font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
                }
                Row { spacing: 8; width: parent.width
                    Rectangle {
                        width: parent.width - 88; height: 36; radius: 8
                        color: "#2C2C2E"; border.color: Qt.rgba(1,1,1,0.1)
                        Text {
                            id: audioDirText
                            anchors.centerIn: parent
                            text: (typeof bridge !== "undefined") ? bridge.get_output_dir() : ""
                            color: "#8E8E93"; font.pixelSize: 11
                            width: parent.width - 16; elide: Text.ElideMiddle
                        }
                    }
                    Rectangle {
                        width: 72; height: 36; radius: 8; color: "#FA2D48"
                        Text { anchors.centerIn: parent; text: "浏览…"; color: "#FFFFFF"; font.pixelSize: 12 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof bridge !== "undefined") {
                                    audioDirText.text = bridge.select_output_dir(audioDirText.text);
                                }
                            }
                        }
                    }
                }
            }

            // 歌词输出目录
            Column { spacing: 8; width: parent.width
                Text {
                    text: "歌词输出目录"
                    color: "#8E8E93"; font.pixelSize: 12
                    font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
                }
                Row { spacing: 8; width: parent.width
                    Rectangle {
                        width: parent.width - 88; height: 36; radius: 8
                        color: "#2C2C2E"; border.color: Qt.rgba(1,1,1,0.1)
                        Text {
                            id: lyricsDirText
                            anchors.centerIn: parent
                            text: (typeof bridge !== "undefined") ? bridge.get_lyrics_output_dir() : ""
                            color: "#8E8E93"; font.pixelSize: 11
                            width: parent.width - 16; elide: Text.ElideMiddle
                        }
                    }
                    Rectangle {
                        width: 72; height: 36; radius: 8; color: "#FA2D48"
                        Text { anchors.centerIn: parent; text: "浏览…"; color: "#FFFFFF"; font.pixelSize: 12 }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof bridge !== "undefined") {
                                    lyricsDirText.text = bridge.select_lyrics_output_dir(lyricsDirText.text);
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
