import QtQuick
import QtQuick.Controls
import "components"

Rectangle {
    id: fileList

    color: "#1A1A1A"
    clip: true

    property var files: []
    property var selectedIndices: []

    // 全区域 DropArea — 覆盖整个文件列表，空列表也能拖入
    DropArea {
        id: fullDropArea
        anchors.fill: parent
        keys: ["text/uri-list"]
        onDropped: function(drop) {
            if (drop.hasUrls && typeof bridge !== "undefined") {
                var paths = [];
                for (var i = 0; i < drop.urls.length; i++) {
                    var raw = String(drop.urls[i]);
                    // 处理不同平台的 URL 格式
                    if (raw.startsWith("file:///")) {
                        raw = raw.replace("file:///", "");
                    } else if (raw.startsWith("file://")) {
                        raw = raw.replace("file://", "");
                    }
                    // Windows 路径处理
                    if (raw.indexOf(":") > 0 && raw[0] === "/") {
                        raw = raw.substring(1);
                    }
                    paths.push(raw);
                }
                bridge.add_files(paths);
            }
        }
    }

    Column {
        anchors.fill: parent

        // 头部 — 操作按钮
        Rectangle {
            width: parent.width
            height: 44
            color: "transparent"

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                GlassButton {
                    btnText: "选择文件"
                    accentColor: "#3A3A3C"
                    onClicked: {
                        // 通过 bridge 触发文件对话框
                        if (typeof bridge !== "undefined") {
                            bridge.open_file_dialog();
                        }
                    }
                }
                GlassButton {
                    btnText: "全选"
                    accentColor: "#3A3A3C"
                    onClicked: {
                        var indices = [];
                        for (var i = 0; i < fileList.files.length; i++) {
                            indices.push(i);
                        }
                        fileList.selectedIndices = indices;
                    }
                }
                GlassButton {
                    btnText: "批量转换"
                    accentColor: "#FA2D48"
                    onClicked: {
                        if (typeof bridge !== "undefined" && fileList.selectedIndices.length > 0) {
                            bridge.batch_convert(fileList.selectedIndices);
                        }
                    }
                }
            }
        }

        // 分隔线
        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

        // 文件列表
        ListView {
            id: listView
            width: parent.width
            height: parent.height - 90
            model: fileList.files
            spacing: 2
            clip: true

            ScrollBar.vertical: ScrollBar {
                policy: ScrollBar.AsNeeded
            }

            delegate: Rectangle {
                width: listView.width
                height: 48
                color: index % 2 === 0 ? "#1A1A1A" : "#1E1E1E"

                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    spacing: 8

                    StatusIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconText: modelData.status_icon || "○"
                        iconColor: modelData.status_color || "#8E8E93"
                        spinning: modelData.status === "processing"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 220
                        Text {
                            text: modelData.filename || ""
                            color: "#FFFFFF"
                            font.pixelSize: 13
                            font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
                            elide: Text.ElideMiddle
                            width: parent.width
                        }
                        Text {
                            text: (modelData.real_format || "").toUpperCase()
                                  + (modelData.bit_depth ? " · " + modelData.bit_depth + "bit" : "")
                                  + (modelData.sample_rate ? " · " + (modelData.sample_rate/1000).toFixed(1) + "kHz" : "")
                            color: "#8E8E93"
                            font.pixelSize: 11
                        }
                    }

                    Item { width: 1; height: 1 }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.duration_str || ""
                        color: "#8E8E93"
                        font.pixelSize: 12
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.file_size_mb || ""
                        color: "#8E8E93"
                        font.pixelSize: 12
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    onClicked: function(mouse) {
                        if (typeof bridge !== "undefined") {
                            bridge.select_file(index);
                        }
                    }
                    onDoubleClicked: {
                        if (typeof bridge !== "undefined") {
                            bridge.play_file(index);
                        }
                    }
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    // 空状态提示
    Text {
        anchors.centerIn: parent
        text: "拖入音频文件到这里\n或点击「选择文件」"
        color: "#555555"
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
        font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
        visible: fileList.files.length === 0
    }
}
