import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Rectangle {
    id: rightPanel
    width: 280
    color: "#1E1E1E"
    property int currentTab: 0
    property var currentTags: ({})
    property string currentLyrics: ""

    Connections {
        target: bridge
        function onTagsLoaded(tags) {
            rightPanel.currentTags = tags;
            rightPanel.currentTags["_changed"] = false;
        }
        function onLyricsLoaded(lyrics) {
            rightPanel.currentLyrics = lyrics;
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // Tab 切换栏
        Rectangle {
            Layout.fillWidth: true; height: 40; color: "#1E1E1E"
            Row {
                anchors.left: parent.left; anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter; spacing: 20

                TabBtn { text: "元数据"; active: rightPanel.currentTab === 0
                    onClicked: rightPanel.currentTab = 0 }
                TabBtn { text: "歌词"; active: rightPanel.currentTab === 1
                    onClicked: rightPanel.currentTab = 1 }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: Qt.rgba(1,1,1,0.06) }

        StackLayout {
            Layout.fillWidth: true; Layout.fillHeight: true
            currentIndex: rightPanel.currentTab

            // --- 元数据 ---
            Flickable {
                anchors.fill: undefined
                contentHeight: metaCol.implicitHeight; clip: true

                ColumnLayout {
                    id: metaCol; width: 248; anchors.margins: 16
                    spacing: 12

                    Text {
                        text: "元数据编辑"; color: "#FFFFFF"
                        font.pixelSize: 16; font.bold: true
                    }

                    Rectangle {
                        Layout.preferredWidth: 200; Layout.preferredHeight: 200
                        Layout.alignment: Qt.AlignHCenter
                        color: "#2C2C2E"; radius: 12
                        border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                        Image {
                            id: coverImage; anchors.fill: parent; anchors.margins: 4
                            fillMode: Image.PreserveAspectFit; source: ""; visible: source != ""
                        }
                        Text {
                            anchors.centerIn: parent; text: "拖入封面"; color: "#8E8E93"
                            font.pixelSize: 13; visible: coverImage.source == ""
                        }
                        DropArea {
                            anchors.fill: parent
                            onDropped: function(drop) {
                                if (drop.hasUrls) {
                                    var p = String(drop.urls[0]).replace("file:///", "");
                                    coverImage.source = "file:///" + p;
                                    rightPanel.currentTags["cover_path"] = p;
                                    rightPanel.currentTags["_cover_changed"] = true;
                                }
                            }
                        }
                    }

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
                            Layout.fillWidth: true; spacing: 4
                            Text { text: modelData.label; color: "#8E8E93"; font.pixelSize: 11 }
                            TextField {
                                id: fld; Layout.fillWidth: true
                                text: rightPanel.currentTags[modelData.key] || ""
                                color: "#FFFFFF"; font.pixelSize: 13
                                background: Rectangle {
                                    color: "#2C2C2E"; radius: 6
                                    border.color: fld.activeFocus ? "#FA2D48" : Qt.rgba(1,1,1,0.1)
                                    border.width: 1
                                }
                                onTextChanged: {
                                    rightPanel.currentTags[modelData.key] = text;
                                    rightPanel.currentTags["_changed"] = true;
                                }
                            }
                        }
                    }

                    GlassButton {
                        Layout.fillWidth: true; btnText: "保存标签"; accentColor: "#FA2D48"
                        onClicked: {
                            if (typeof bridge !== "undefined" && rightPanel.currentTags["_changed"]) {
                                bridge.save_tags(rightPanel.currentTags);
                                rightPanel.currentTags["_changed"] = false;
                            }
                        }
                    }
                }
            }

            // --- 歌词 ---
            ColumnLayout {
                anchors.margins: 16; spacing: 12

                Text {
                    text: "歌词编辑"; color: "#FFFFFF"
                    font.pixelSize: 16; font.bold: true
                }

                ScrollView {
                    Layout.fillWidth: true; Layout.fillHeight: true; clip: true
                    TextArea {
                        id: lyricsArea; width: 248
                        color: "#FFFFFF"; font.pixelSize: 13
                        placeholderText: "在此编写歌词…"
                        placeholderTextColor: "#555555"
                        background: Rectangle {
                            color: "#2C2C2E"; radius: 8
                            border.color: Qt.rgba(1,1,1,0.1)
                        }
                        wrapMode: TextArea.Wrap
                        text: rightPanel.currentLyrics
                        onTextChanged: rightPanel.currentLyrics = text
                    }
                }

                Row {
                    Layout.fillWidth: true; spacing: 8
                    GlassButton {
                        btnText: "保存到文件"; accentColor: "#FA2D48"
                        onClicked: {
                            if (typeof bridge !== "undefined") {
                                bridge.save_lyrics(bridge.selectedIndex, rightPanel.currentLyrics);
                            }
                        }
                    }
                    GlassButton {
                        btnText: "导出 .lrc"; accentColor: "#3A3A3C"
                        onClicked: {
                            if (typeof bridge !== "undefined") {
                                var path = bridge.export_lyrics(bridge.selectedIndex, rightPanel.currentLyrics);
                                if (path) rightPanel.currentLyrics = "\n[导出: " + path + "]";
                            }
                        }
                    }
                }
            }
        }
    }
}
