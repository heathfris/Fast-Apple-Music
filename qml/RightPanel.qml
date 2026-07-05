import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import "components"

Rectangle {
    id: rightPanel
    width: 260
    color: "#1E1E1E"
    property int currentTab: 0
    property var currentTags: ({})
    property string currentLyrics: ""
    property var currentIndices: []
    property int selectedCount: 0
    property bool saveSuccess: false
    property string saveErrorMessage: ""

    // 流派下拉列表数据
    property var genreList: []

    Component.onCompleted: {
        if (typeof bridge !== "undefined") {
            genreList = bridge.get_genres();
        }
    }

    Connections {
        target: bridge
        function onTagsLoaded(tags) {
            rightPanel.currentTags = tags;
            rightPanel.currentTags["_changed"] = false;
            // 使用 tags 中携带的索引（_on_task_finished 已注入）
            // 空对象表示清空选择
            if (tags && Object.keys(tags).length > 0) {
                rightPanel.currentIndices = tags["_indices"] || [bridge.selectedIndex];
                rightPanel.selectedCount = tags["_count"] || 1;
            } else {
                rightPanel.currentIndices = [];
                rightPanel.selectedCount = 0;
            }
        }
        function onMultiTagsLoaded(tags) {
            rightPanel.currentTags = tags;
            rightPanel.currentTags["_changed"] = false;
            rightPanel.currentIndices = tags["_indices"] || [];
            rightPanel.selectedCount = tags["_count"] || rightPanel.currentIndices.length;
        }
        function onTagsSaved(count) {
            if (count > 0) {
                rightPanel.saveSuccess = true;
                rightPanel.saveErrorMessage = "";
                saveSuccessTimer.restart();
            }
        }
        function onSaveError(msg) {
            rightPanel.saveSuccess = false;
            rightPanel.saveErrorMessage = msg;
            saveErrorTimer.restart();
        }
        function onLyricsLoaded(lyrics) {
            rightPanel.currentLyrics = lyrics;
        }
    }

    // 辅助：标签 label 是否显示红色 *
    function hasDiffer(key) {
        return rightPanel.currentTags[key + "_differ"] === true;
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        // 多选提示条
        Rectangle {
            Layout.fillWidth: true
            height: rightPanel.selectedCount > 1 ? 28 : 0
            visible: rightPanel.selectedCount > 1
            color: Qt.rgba(250/255, 45/255, 72/255, 0.12)
            Text {
                anchors.centerIn: parent
                text: "已选 " + rightPanel.selectedCount + " 首  —  相同字段显示，不同字段标记 *"
                color: "#FA2D48"
                font.pixelSize: 11
                font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
            }
        }

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

            // ============================================================
            // 元数据面板
            // ============================================================
            Flickable {
                contentHeight: metaCol.implicitHeight; clip: true

                ColumnLayout {
                    id: metaCol
                    width: parent.width - 20
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    anchors.topMargin: 12
                    spacing: 10

                    // 封面
                    Rectangle {
                        Layout.preferredWidth: 160; Layout.preferredHeight: 160
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

                    // --- 表单字段 ---
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        // 曲名
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "曲名"
                                color: "#8E8E93"; font.pixelSize: 11
                            }
                            Text {
                                text: "*"
                                color: "#FA2D48"; font.pixelSize: 12
                                visible: rightPanel.hasDiffer("title")
                            }
                        }
                        TextField {
                            id: fldTitle; Layout.fillWidth: true
                            text: rightPanel.currentTags["title"] || ""
                            color: "#FFFFFF"; font.pixelSize: 13
                            background: Rectangle {
                                color: "#2C2C2E"; radius: 6
                                border.color: fldTitle.activeFocus ? "#FA2D48" : Qt.rgba(1,1,1,0.1)
                                border.width: 1
                            }
                            onTextChanged: {
                                rightPanel.currentTags["title"] = text;
                                rightPanel.currentTags["_changed"] = true;
                            }
                        }

                        // 艺人
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "艺人"
                                color: "#8E8E93"; font.pixelSize: 11
                            }
                            Text {
                                text: "*"
                                color: "#FA2D48"; font.pixelSize: 12
                                visible: rightPanel.hasDiffer("artist")
                            }
                        }
                        TextField {
                            id: fldArtist; Layout.fillWidth: true
                            text: rightPanel.currentTags["artist"] || ""
                            color: "#FFFFFF"; font.pixelSize: 13
                            background: Rectangle {
                                color: "#2C2C2E"; radius: 6
                                border.color: fldArtist.activeFocus ? "#FA2D48" : Qt.rgba(1,1,1,0.1)
                                border.width: 1
                            }
                            onTextChanged: {
                                rightPanel.currentTags["artist"] = text;
                                rightPanel.currentTags["_changed"] = true;
                            }
                        }

                        // 专辑
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "专辑"
                                color: "#8E8E93"; font.pixelSize: 11
                            }
                            Text {
                                text: "*"
                                color: "#FA2D48"; font.pixelSize: 12
                                visible: rightPanel.hasDiffer("album")
                            }
                        }
                        TextField {
                            id: fldAlbum; Layout.fillWidth: true
                            text: rightPanel.currentTags["album"] || ""
                            color: "#FFFFFF"; font.pixelSize: 13
                            background: Rectangle {
                                color: "#2C2C2E"; radius: 6
                                border.color: fldAlbum.activeFocus ? "#FA2D48" : Qt.rgba(1,1,1,0.1)
                                border.width: 1
                            }
                            onTextChanged: {
                                rightPanel.currentTags["album"] = text;
                                rightPanel.currentTags["_changed"] = true;
                            }
                        }

                        // 专辑艺人
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "专辑艺人"
                                color: "#8E8E93"; font.pixelSize: 11
                            }
                            Text {
                                text: "*"
                                color: "#FA2D48"; font.pixelSize: 12
                                visible: rightPanel.hasDiffer("album_artist")
                            }
                        }
                        TextField {
                            id: fldAlbumArtist; Layout.fillWidth: true
                            text: rightPanel.currentTags["album_artist"] || ""
                            color: "#FFFFFF"; font.pixelSize: 13
                            background: Rectangle {
                                color: "#2C2C2E"; radius: 6
                                border.color: fldAlbumArtist.activeFocus ? "#FA2D48" : Qt.rgba(1,1,1,0.1)
                                border.width: 1
                            }
                            onTextChanged: {
                                rightPanel.currentTags["album_artist"] = text;
                                rightPanel.currentTags["_changed"] = true;
                            }
                        }

                        // 作曲
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "作曲"
                                color: "#8E8E93"; font.pixelSize: 11
                            }
                            Text {
                                text: "*"
                                color: "#FA2D48"; font.pixelSize: 12
                                visible: rightPanel.hasDiffer("composer")
                            }
                        }
                        TextField {
                            id: fldComposer; Layout.fillWidth: true
                            text: rightPanel.currentTags["composer"] || ""
                            color: "#FFFFFF"; font.pixelSize: 13
                            background: Rectangle {
                                color: "#2C2C2E"; radius: 6
                                border.color: fldComposer.activeFocus ? "#FA2D48" : Qt.rgba(1,1,1,0.1)
                                border.width: 1
                            }
                            onTextChanged: {
                                rightPanel.currentTags["composer"] = text;
                                rightPanel.currentTags["_changed"] = true;
                            }
                        }

                        // 年份
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "年份"
                                color: "#8E8E93"; font.pixelSize: 11
                            }
                            Text {
                                text: "*"
                                color: "#FA2D48"; font.pixelSize: 12
                                visible: rightPanel.hasDiffer("year")
                            }
                        }
                        TextField {
                            id: fldYear; Layout.fillWidth: true
                            text: rightPanel.currentTags["year"] || ""
                            color: "#FFFFFF"; font.pixelSize: 13
                            background: Rectangle {
                                color: "#2C2C2E"; radius: 6
                                border.color: fldYear.activeFocus ? "#FA2D48" : Qt.rgba(1,1,1,0.1)
                                border.width: 1
                            }
                            onTextChanged: {
                                rightPanel.currentTags["year"] = text;
                                rightPanel.currentTags["_changed"] = true;
                            }
                        }

                        // 流派 — 带下拉按钮
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                text: "流派"
                                color: "#8E8E93"; font.pixelSize: 11
                            }
                            Text {
                                text: "*"
                                color: "#FA2D48"; font.pixelSize: 12
                                visible: rightPanel.hasDiffer("genre")
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 0
                            TextField {
                                id: fldGenre
                                Layout.fillWidth: true
                                text: rightPanel.currentTags["genre"] || ""
                                color: "#FFFFFF"; font.pixelSize: 13
                                background: Rectangle {
                                    color: "#2C2C2E"; radius: 6
                                    border.color: fldGenre.activeFocus ? "#FA2D48" : Qt.rgba(1,1,1,0.1)
                                    border.width: 1
                                }
                                onTextChanged: {
                                    rightPanel.currentTags["genre"] = text;
                                    rightPanel.currentTags["_changed"] = true;
                                }
                            }
                            // 下拉按钮
                            Rectangle {
                                width: 28; height: 36
                                color: genreBtnMa.containsMouse ? Qt.rgba(1,1,1,0.08) : "transparent"
                                radius: 6
                                Text {
                                    anchors.centerIn: parent
                                    text: "▼"
                                    color: "#8E8E93"; font.pixelSize: 9
                                }
                                MouseArea {
                                    id: genreBtnMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: genrePopup.open()
                                }
                            }
                        }

                        // 流派下拉 Popup
                        Popup {
                            id: genrePopup
                            y: fldGenre.height
                            width: fldGenre.width + 28
                            height: 300
                            padding: 4
                            background: Rectangle {
                                color: "#2C2C2E"; radius: 8
                                border.color: Qt.rgba(1,1,1,0.15)
                            }

                            ColumnLayout {
                                anchors.fill: parent
                                spacing: 0

                                // 搜索过滤
                                TextField {
                                    id: genreFilter
                                    Layout.fillWidth: true
                                    placeholderText: "搜索流派…"
                                    placeholderTextColor: "#555555"
                                    color: "#FFFFFF"; font.pixelSize: 13
                                    background: Rectangle {
                                        color: "#1E1E1E"; radius: 6
                                        border.color: Qt.rgba(1,1,1,0.1); border.width: 1
                                    }
                                }

                                ListView {
                                    id: genreListView
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    clip: true
                                    model: rightPanel.genreList.filter(function(g) {
                                        return g.toLowerCase().indexOf(genreFilter.text.toLowerCase()) >= 0;
                                    })
                                    delegate: Rectangle {
                                        width: genreListView.width
                                        height: 32
                                        color: genreItemMa.containsMouse ? Qt.rgba(250/255, 45/255, 72/255, 0.15) : "transparent"
                                        radius: 4
                                        Text {
                                            anchors.verticalCenter: parent.verticalCenter
                                            anchors.left: parent.left; anchors.leftMargin: 10
                                            text: modelData
                                            color: "#FFFFFF"; font.pixelSize: 13
                                            elide: Text.ElideRight; width: parent.width - 20
                                        }
                                        MouseArea {
                                            id: genreItemMa
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                fldGenre.text = modelData;
                                                rightPanel.currentTags["genre"] = modelData;
                                                rightPanel.currentTags["_changed"] = true;
                                                genrePopup.close();
                                                genreFilter.text = "";
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // 保存按钮 + 成功/错误指示
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        GlassButton {
                            Layout.fillWidth: true
                            btnText: rightPanel.selectedCount > 1
                                ? "保存标签到 " + rightPanel.selectedCount + " 个文件"
                                : "保存标签"
                            accentColor: "#FA2D48"
                            onClicked: {
                                if (typeof bridge !== "undefined") {
                                    rightPanel.currentTags["_indices"] = rightPanel.currentIndices;
                                    bridge.save_tags(rightPanel.currentTags);
                                    rightPanel.currentTags["_changed"] = false;
                                }
                            }
                        }

                        // 保存成功绿色圆点
                        Rectangle {
                            width: 14; height: 14; radius: 7
                            color: "#34C759"
                            opacity: rightPanel.saveSuccess ? 1.0 : 0.0
                            visible: opacity > 0
                            Behavior on opacity { NumberAnimation { duration: 250 } }
                        }
                    }

                    // 错误信息
                    Text {
                        Layout.fillWidth: true
                        text: rightPanel.saveErrorMessage
                        color: "#FF3B30"
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                        visible: rightPanel.saveErrorMessage != ""
                    }

                    // 底部留白 — 防止被播放栏遮挡
                    Item { Layout.preferredHeight: 60 }
                }
            }

            // 保存成功/错误自动隐藏定时器
            Timer {
                id: saveSuccessTimer
                interval: 3000
                repeat: false
                onTriggered: rightPanel.saveSuccess = false
            }
            Timer {
                id: saveErrorTimer
                interval: 8000
                repeat: false
                onTriggered: rightPanel.saveErrorMessage = ""
            }

            // ============================================================
            // 歌词面板
            // ============================================================
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12

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

                // 多选提示
                Text {
                    Layout.fillWidth: true
                    text: rightPanel.selectedCount > 1 && rightPanel.currentTags["lyrics_differ"] === true
                        ? "* 所选文件歌词内容不同，编辑后将对 " + rightPanel.selectedCount + " 个文件统一写入"
                        : ""
                    color: "#FA2D48"
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    visible: text != ""
                }

                Row {
                    Layout.fillWidth: true; spacing: 8
                    GlassButton {
                        btnText: rightPanel.selectedCount > 1
                            ? "嵌入歌词到 " + rightPanel.selectedCount + " 个文件"
                            : "嵌入歌词到文件"
                        accentColor: "#FA2D48"
                        onClicked: {
                            if (typeof bridge !== "undefined" && rightPanel.currentIndices.length > 0) {
                                bridge.save_lyrics(rightPanel.currentIndices, rightPanel.currentLyrics);
                            }
                        }
                    }
                    GlassButton {
                        btnText: "导出 .lrc"; accentColor: "#3A3A3C"
                        onClicked: {
                            if (typeof bridge !== "undefined" && rightPanel.currentIndices.length > 0) {
                                var path = bridge.export_lyrics(rightPanel.currentIndices, rightPanel.currentLyrics);
                                if (path) {
                                    exportPathLabel.text = "已导出: " + path;
                                    exportPathLabel.visible = true;
                                    exportPathTimer.restart();
                                }
                            }
                        }
                    }

                    // 导出成功提示
                    Text {
                        id: exportPathLabel
                        text: ""
                        color: "#34C759"
                        font.pixelSize: 11
                        elide: Text.ElideMiddle
                        visible: false
                    }
                    Timer {
                        id: exportPathTimer
                        interval: 5000
                        repeat: false
                        onTriggered: exportPathLabel.visible = false
                    }

                    // 底部留白
                    Item { Layout.preferredHeight: 60 }
                }
            }
        }
    }
}
