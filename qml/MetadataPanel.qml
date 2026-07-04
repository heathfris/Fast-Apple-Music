import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Rectangle {
    id: metadataPanel

    width: 280
    color: "#1E1E1E"

    property var currentTags: ({})

    Flickable {
        anchors.fill: parent
        anchors.margins: 16
        contentHeight: column.implicitHeight
        clip: true

        ColumnLayout {
            id: column
            width: parent.width
            spacing: 12

            Text {
                text: "元数据编辑"
                color: "#FFFFFF"
                font.pixelSize: 16
                font.bold: true
                font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
            }

            // 专辑封面
            Rectangle {
                Layout.preferredWidth: 200
                Layout.preferredHeight: 200
                Layout.alignment: Qt.AlignHCenter
                color: "#2C2C2E"
                radius: 12
                border.color: Qt.rgba(1, 1, 1, 0.1)
                border.width: 1

                Image {
                    id: coverImage
                    anchors.fill: parent
                    anchors.margins: 4
                    fillMode: Image.PreserveAspectFit
                    source: ""
                    visible: source != ""
                }

                Text {
                    anchors.centerIn: parent
                    text: "拖入封面图片"
                    color: "#8E8E93"
                    font.pixelSize: 13
                    visible: coverImage.source == ""
                }

                DropArea {
                    anchors.fill: parent
                    onDropped: function(drop) {
                        if (drop.hasUrls) {
                            var path = String(drop.urls[0]).replace("file:///", "");
                            coverImage.source = "file:///" + path;
                            metadataPanel.currentTags["cover_path"] = path;
                            metadataPanel.currentTags["_cover_changed"] = true;
                        }
                    }
                }
            }

            // 表单字段
            Repeater {
                model: [
                    { key: "title", label: "曲名" },
                    { key: "artist", label: "艺人" },
                    { key: "album", label: "专辑" },
                    { key: "album_artist", label: "专辑艺人" },
                    { key: "composer", label: "作曲" },
                    { key: "year", label: "年份" },
                    { key: "genre", label: "流派" }
                ]

                delegate: ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 4

                    Text {
                        text: modelData.label
                        color: "#8E8E93"
                        font.pixelSize: 11
                        font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
                    }

                    TextField {
                        id: field
                        Layout.fillWidth: true
                        text: metadataPanel.currentTags[modelData.key] || ""
                        color: "#FFFFFF"
                        font.pixelSize: 13
                        font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"

                        background: Rectangle {
                            color: "#2C2C2E"
                            radius: 6
                            border.color: field.activeFocus ? "#FA2D48" : Qt.rgba(1,1,1,0.1)
                            border.width: 1
                        }

                        onTextChanged: {
                            metadataPanel.currentTags[modelData.key] = text;
                            metadataPanel.currentTags["_changed"] = true;
                        }
                    }
                }
            }

            // 保存按钮
            GlassButton {
                Layout.fillWidth: true
                btnText: "保存标签"
                accentColor: "#FA2D48"
                onClicked: {
                    if (typeof bridge !== "undefined" && metadataPanel.currentTags["_changed"]) {
                        bridge.save_tags(metadataPanel.currentTags);
                        metadataPanel.currentTags["_changed"] = false;
                    }
                }
            }
        }
    }
}
