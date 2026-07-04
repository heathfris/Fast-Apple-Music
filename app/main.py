"""Fast Apple Music — 应用入口"""
import sys
import os
import tempfile
from PySide6.QtCore import QUrl, QObject, Slot, Signal, Property, QTimer
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QFileDialog, QApplication

from app.engine.converter import ConversionEngine
from app.engine.worker import TaskWorker
from app.engine.player import PlayerController
from app.models.audiofile import AudioFile, AudioStatus
from app.models.task import Task, TaskType
from app.metadata.reader import read_tags
from app.metadata.writer import write_tags


class AppBridge(QObject):
    """Python ↔ QML 桥接对象"""

    filesChanged = Signal()
    playerStateChanged = Signal()
    tagsLoaded = Signal("QVariantMap")

    def __init__(self, parent=None):
        super().__init__(parent)
        self._engine = ConversionEngine()
        self._files: list[AudioFile] = []
        self._selected_index: int = -1
        self._output_dir = tempfile.gettempdir()
        self._last_tags: dict = {}

        self._player = PlayerController()

        self._worker = TaskWorker()
        self._worker.task_finished.connect(self._on_task_finished)
        self._worker.task_failed.connect(self._on_task_failed)
        self._worker.start()

        # 同步播放进度
        self._timer = QTimer()
        self._timer.timeout.connect(self._sync_player)
        self._timer.start(200)

    # --- 文件管理 ---

    @Slot("QVariantList")
    def add_files(self, paths: list):
        for p in paths:
            path = str(p)
            if not os.path.isfile(path):
                continue
            if any(f.path == path for f in self._files):
                continue
            af = self._engine.analyze(path)
            self._files.append(af)
        self.filesChanged.emit()

    @Slot()
    def clear_files(self):
        self._files.clear()
        self.filesChanged.emit()

    @Slot()
    def open_file_dialog(self):
        """打开文件选择对话框"""
        paths, _ = QFileDialog.getOpenFileNames(
            None,
            "选择音频文件",
            "",
            "音频文件 (*.mp3 *.flac *.wav *.aiff *.aac *.m4a *.alac *.wma *.ogg);;所有文件 (*.*)"
        )
        if paths:
            self.add_files(paths)

    # --- 转换 ---

    @Slot("QVariantList")
    def batch_convert(self, indices: list):
        for idx in indices:
            if idx < 0 or idx >= len(self._files):
                continue
            af = self._files[idx]
            task = Task(
                task_id="",
                task_type=TaskType.CONVERT,
                file_path=af.path,
                kwargs={"output_dir": self._output_dir},
            )
            self._worker.add_task(task)

    @Slot(int, result="QVariantMap")
    def get_file(self, index: int) -> dict:
        if 0 <= index < len(self._files):
            return self._files[index].to_dict()
        return {}

    @Slot(result="QVariantList")
    def get_all_files(self) -> list:
        return [f.to_dict() for f in self._files]

    # --- 播放 ---

    @Slot(int)
    def play_file(self, index: int):
        if 0 <= index < len(self._files):
            af = self._files[index]
            target = af.output_path if af.output_path else af.path
            self._player.play_file(target)
            self._selected_index = index
            self.playerStateChanged.emit()

    @Slot()
    def toggle_play(self):
        self._player.toggle_play()

    @Slot(int)
    def seek(self, ms: int):
        self._player.seek(ms)

    @Slot(int)
    def select_file(self, index: int):
        if 0 <= index < len(self._files):
            self._selected_index = index
            af = self._files[index]
            target = af.output_path if af.output_path else af.path
            task = Task(
                task_id="",
                task_type=TaskType.READ_TAGS,
                file_path=target,
                kwargs={},
            )
            self._worker.add_task(task)

    # --- 元数据 ---

    @Slot("QVariantMap")
    def save_tags(self, tags: dict):
        if self._selected_index < 0:
            return
        af = self._files[self._selected_index]
        target = af.output_path if af.output_path else af.path

        cover_path = tags.get("cover_path", "")
        cover_data = None
        if cover_path and os.path.isfile(cover_path):
            with open(cover_path, "rb") as f:
                cover_data = f.read()

        clean_tags = {k: v for k, v in tags.items()
                      if not k.startswith("_") and k != "cover_path"}
        if cover_data:
            clean_tags["cover_data"] = cover_data

        task = Task(
            task_id="",
            task_type=TaskType.WRITE_TAGS,
            file_path=target,
            kwargs={"tags": clean_tags},
        )
        self._worker.add_task(task)

    # --- 设置 ---

    @Slot(str)
    def set_output_dir(self, path: str):
        self._output_dir = path

    # --- 内部回调 ---

    def _on_task_finished(self, task_id: str, result):
        if isinstance(result, AudioFile):
            for i, f in enumerate(self._files):
                # 匹配原始路径或输出路径（标签写入任务的结果 path 是输出路径）
                if f.path == result.path or f.output_path == result.path:
                    self._files[i] = result
                    break
            self.filesChanged.emit()
        elif isinstance(result, dict) and "title" in result:
            self._last_tags = result
            self.tagsLoaded.emit(result)

    def _on_task_failed(self, task_id: str, error: str):
        print(f"Task {task_id} failed: {error}")

    def _sync_player(self):
        self.playerStateChanged.emit()

    # --- QML 属性 (with notify signals so QML bindings re-evaluate) ---

    @Property(float, notify=playerStateChanged)
    def currentPosition(self) -> float:
        return float(self._player.position())

    @Property(float, notify=playerStateChanged)
    def totalDuration(self) -> float:
        return float(self._player.duration())

    @Property(bool, notify=playerStateChanged)
    def isPlaying(self) -> bool:
        return self._player.isPlaying()

    @Property(str, notify=playerStateChanged)
    def currentTitle(self) -> str:
        if 0 <= self._selected_index < len(self._files):
            return self._files[self._selected_index].filename
        return ""


def main():
    app = QApplication(sys.argv)
    app.setOrganizationName("FastAppleMusic")
    app.setApplicationName("Fast Apple Music")

    bridge = AppBridge()

    qml_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "qml")
    engine = QQmlApplicationEngine()

    context = engine.rootContext()
    context.setContextProperty("bridge", bridge)

    engine.load(QUrl.fromLocalFile(os.path.join(qml_dir, "main.qml")))

    if not engine.rootObjects():
        print("Failed to load QML")
        sys.exit(1)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
