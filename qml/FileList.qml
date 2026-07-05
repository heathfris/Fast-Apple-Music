import QtQuick
import QtQuick.Controls
import "components"

Rectangle {
    id: fileList

    color: "#1A1A1A"
    clip: true

    property var files: []
    property var selectedIndices: []

    // 监听 bridge 数据变化 — 核心连接
    Connections {
        target: bridge
        function onFilesChanged() {
            fileList.files = bridge.get_all_files();
            // 清理已经不存在的索引
            var valid = [];
            for (var i = 0; i < fileList.selectedIndices.length; i++) {
                if (fileList.selectedIndices[i] < fileList.files.length) {
                    valid.push(fileList.selectedIndices[i]);
                }
            }
            fileList.selectedIndices = valid;
            // 刷新右侧元数据（删除后自动更新或清空）
            if (typeof bridge !== "undefined") {
                bridge.load_selected_tags(fileList.selectedIndices);
            }
        }
    }

    Component.onCompleted: {
        if (typeof bridge !== "undefined") {
            fileList.files = bridge.get_all_files();
        }
    }

    // 辅助函数：切换选中
    function toggleSelection(idx) {
        var arr = fileList.selectedIndices.slice();
        var pos = arr.indexOf(idx);
        if (pos >= 0) {
            arr.splice(pos, 1);
        } else {
            arr.push(idx);
        }
        fileList.selectedIndices = arr;
    }

    function isSelected(idx) {
        return fileList.selectedIndices.indexOf(idx) >= 0;
    }

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
                    if (raw.startsWith("file:///")) {
                        raw = raw.replace("file:///", "");
                    } else if (raw.startsWith("file://")) {
                        raw = raw.replace("file://", "");
                    }
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
                        if (typeof bridge !== "undefined") {
                            bridge.open_file_dialog();
                        }
                    }
                }
                GlassButton {
                    btnText: "全选"
                    accentColor: "#3A3A3C"
                    onClicked: {
                        if (fileList.selectedIndices.length === fileList.files.length) {
                            fileList.selectedIndices = [];
                        } else {
                            var indices = [];
                            for (var i = 0; i < fileList.files.length; i++) {
                                indices.push(i);
                            }
                            fileList.selectedIndices = indices;
                        }
                        if (typeof bridge !== "undefined") {
                            bridge.load_selected_tags(fileList.selectedIndices);
                        }
                    }
                }
                GlassButton {
                    btnText: "批量转换"
                    accentColor: "#FA2D48"
                    onClicked: {
                        if (typeof bridge !== "undefined") {
                            // 没手动选中的话，转换全部
                            var targets = fileList.selectedIndices.length > 0
                                ? fileList.selectedIndices
                                : (function() {
                                    var all = [];
                                    for (var i = 0; i < fileList.files.length; i++) { all.push(i); }
                                    return all;
                                  })();
                            if (targets.length > 0) {
                                bridge.batch_convert(targets);
                            }
                        }
                    }
                }
                GlassButton {
                    btnText: "清空"
                    accentColor: "#3A3A3C"
                    onClicked: {
                        if (typeof bridge !== "undefined") {
                            bridge.clear_files();
                            fileList.selectedIndices = [];
                        }
                    }
                }
            }
        }

        Rectangle {
            width: parent.width
            height: 1
            color: Qt.rgba(1, 1, 1, 0.06)
        }

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
                id: rowDelegate
                width: listView.width
                height: 48
                color: fileList.isSelected(index)
                       ? Qt.rgba(250/255, 45/255, 72/255, 0.18)
                       : (index % 2 === 0 ? "#1A1A1A" : "#1E1E1E")

                Behavior on color { ColorAnimation { duration: 120 } }

                // 左侧选中指示条
                Rectangle {
                    width: 3
                    height: parent.height
                    color: fileList.isSelected(index) ? "#FA2D48" : "transparent"
                    Behavior on color { ColorAnimation { duration: 120 } }
                }

                // 文件图标 + 名称
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 15
                    spacing: 8

                    StatusIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        iconText: modelData.status_icon || "○"
                        iconColor: modelData.status_color || "#8E8E93"
                        spinning: modelData.status === "processing"
                    }

                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        width: Math.min(260, parent.parent.width - 200)
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
                }

                // 时长 — 右对齐
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: fileSizeText.left
                    anchors.rightMargin: 10
                    text: modelData.duration_str || ""
                    color: "#8E8E93"
                    font.pixelSize: 12
                }

                // 文件大小
                Text {
                    id: fileSizeText
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: deleteBtn.left
                    anchors.rightMargin: 10
                    text: modelData.file_size_mb || ""
                    color: "#8E8E93"
                    font.pixelSize: 12
                }

                // 删除按钮 — 绝对定位在右侧
                Rectangle {
                    id: deleteBtn
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    width: 26; height: 26; radius: 13
                    color: deleteBtnMa.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: deleteBtnMa.containsMouse ? "#FF3B30" : "#666666"
                        font.pixelSize: 12
                    }

                    MouseArea {
                        id: deleteBtnMa
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: function(mouse) {
                            mouse.accepted = true;
                            if (typeof bridge !== "undefined") {
                                bridge.delete_file(index);
                            }
                        }
                    }
                }

                // 主点击区域 — 不覆盖删除按钮
                // 单击：单选；Ctrl+单击：多选；双击：播放
                MouseArea {
                    anchors.fill: parent
                    anchors.rightMargin: 44
                    acceptedButtons: Qt.LeftButton
                    onClicked: function(mouse) {
                        if (mouse.modifiers & Qt.ControlModifier) {
                            // Ctrl+单击：追加/取消选择
                            fileList.toggleSelection(index);
                        } else {
                            // 普通单击：单选
                            fileList.selectedIndices = [index];
                        }
                        // 加载选中文件的标签到右侧面板
                        if (typeof bridge !== "undefined") {
                            bridge.load_selected_tags(fileList.selectedIndices);
                        }
                    }
                    onDoubleClicked: {
                        if (typeof bridge !== "undefined") {
                            bridge.select_file(index);
                            bridge.play_file(index);
                        }
                    }
                    cursorShape: Qt.PointingHandCursor
                }
            }
        }
    }

    Text {
        anchors.centerIn: parent
        text: "拖入音频文件到这里\n或点击「选择文件」"
        color: "#555555"
        font.pixelSize: 18
        horizontalAlignment: Text.AlignHCenter
        font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
        visible: fileList.files.length === 0
    }

    // 操作提示 — 文件列表底部，3 秒后渐隐
    Text {
        id: hintText
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        text: "单击选择并查看元数据，双击播放"
        color: "#444444"
        font.pixelSize: 12
        font.family: Qt.platform.os === "osx" ? "SF Pro Display" : "Segoe UI"
        opacity: 1.0
        visible: fileList.files.length > 0

        Behavior on opacity {
            NumberAnimation { duration: 800; easing.type: Easing.OutCubic }
        }

        Timer {
            id: hintTimer
            interval: 3000
            running: fileList.files.length > 0
            repeat: false
            onTriggered: hintText.opacity = 0
        }
    }
}
