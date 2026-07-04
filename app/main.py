"""Fast Apple Music — 应用入口"""
import sys
import os
import tempfile
import json
from datetime import datetime
from PySide6.QtCore import QUrl, QObject, Slot, Signal, Property, QTimer
from PySide6.QtGui import QIcon
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QFileDialog, QApplication

from app.engine.converter import ConversionEngine
from app.engine.worker import TaskWorker
from app.engine.player import PlayerController
from app.models.audiofile import AudioFile, AudioStatus
from app.models.task import Task, TaskType
from app.metadata.reader import read_tags
from app.metadata.writer import write_tags


def _fix_frameless_window(hwnd_ptr):
    """Win32 API: restore taskbar minimize/restore for frameless window"""
    import ctypes
    from ctypes import wintypes
    try:
        hwnd = int(hwnd_ptr)
        GWL_STYLE = -16
        WS_MINIMIZEBOX = 0x00020000
        style = ctypes.windll.user32.GetWindowLongPtrW(hwnd, GWL_STYLE)
        ctypes.windll.user32.SetWindowLongPtrW(
            hwnd, GWL_STYLE, style | WS_MINIMIZEBOX
        )
    except Exception:
        pass


def _apply_win11_rounded_corners(hwnd_ptr):
    """Win11 DWM API: apply native rounded corners"""
    import ctypes
    try:
        hwnd = int(hwnd_ptr)
        DWMWA_WINDOW_CORNER_PREFERENCE = 33
        DWMWCP_ROUND = 2
        ctypes.windll.dwmapi.DwmSetWindowAttribute(
            hwnd, DWMWA_WINDOW_CORNER_PREFERENCE,
            ctypes.byref(ctypes.c_int(DWMWCP_ROUND)),
            ctypes.sizeof(ctypes.c_int)
        )
    except Exception:
        pass  # 非 Win11 静默降级


def _read_lyrics(path: str) -> str:
    """从音频文件中读取歌词"""
    try:
        tags = read_tags(path)
        return tags.get("lyrics", "")
    except Exception:
        return ""


def _write_lyrics(path: str, lyrics: str):
    """将歌词写入音频文件"""
    try:
        tags = read_tags(path)
        tags["lyrics"] = lyrics
        write_tags(path, tags)
    except Exception:
        pass


class AppBridge(QObject):
    """Python ↔ QML 桥接对象"""

    filesChanged = Signal()
    playerStateChanged = Signal()
    tagsLoaded = Signal("QVariantMap")
    lyricsLoaded = Signal(str)

    def __init__(self, parent=None):
        super().__init__(parent)
        self._engine = ConversionEngine()
        self._files: list[AudioFile] = []
        self._selected_index: int = -1
        self._output_dir = tempfile.gettempdir()
        self._lyrics_output_dir = tempfile.gettempdir()
        self._last_tags: dict = {}
        self._conversion_history: list[dict] = []

        self._player = PlayerController()

        self._worker = TaskWorker()
        self._worker.task_finished.connect(self._on_task_finished)
        self._worker.task_failed.connect(self._on_task_failed)
        self._worker.start()

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
        self._player.stop()
        self._selected_index = -1
        self._files.clear()
        self.filesChanged.emit()
        self.playerStateChanged.emit()

    @Slot(int)
    def delete_file(self, index: int):
        if index < 0 or index >= len(self._files):
            return
        if index == self._selected_index:
            self._player.stop()
            self._selected_index = -1
            self.playerStateChanged.emit()
        self._files.pop(index)
        self.filesChanged.emit()

    @Slot()
    def open_file_dialog(self):
        paths, _ = QFileDialog.getOpenFileNames(
            None, "选择音频文件", "",
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
            af.status = AudioStatus.PROCESSING
            task = Task(
                task_id="", task_type=TaskType.CONVERT,
                file_path=af.path,
                kwargs={"output_dir": self._output_dir},
            )
            self._worker.add_task(task)
        self.filesChanged.emit()

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
            # 读取标签
            task = Task(
                task_id="", task_type=TaskType.READ_TAGS,
                file_path=target, kwargs={},
            )
            self._worker.add_task(task)
            # 读取歌词
            lyrics = _read_lyrics(target)
            self.lyricsLoaded.emit(lyrics)

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
            task_id="", task_type=TaskType.WRITE_TAGS,
            file_path=target, kwargs={"tags": clean_tags},
        )
        self._worker.add_task(task)

    # --- 歌词 ---

    @Slot(int, result=str)
    def get_lyrics(self, index: int) -> str:
        if 0 <= index < len(self._files):
            af = self._files[index]
            target = af.output_path if af.output_path else af.path
            return _read_lyrics(target)
        return ""

    @Slot(int, str)
    def save_lyrics(self, index: int, lyrics: str):
        if 0 <= index < len(self._files):
            af = self._files[index]
            target = af.output_path if af.output_path else af.path
            _write_lyrics(target, lyrics)

    @Slot(int, str, result=str)
    def export_lyrics(self, index: int, lyrics: str) -> str:
        """导出歌词为 .lrc 文件，返回文件路径"""
        if 0 <= index < len(self._files):
            af = self._files[index]
            basename = os.path.splitext(af.filename)[0]
            lrc_path = os.path.join(self._lyrics_output_dir, f"{basename}.lrc")
            with open(lrc_path, "w", encoding="utf-8") as f:
                f.write(lyrics)
            return lrc_path
        return ""

    # --- 设置 ---

    @Slot(str)
    def set_output_dir(self, path: str):
        if os.path.isdir(path):
            self._output_dir = path

    @Slot(result=str)
    def get_output_dir(self) -> str:
        return self._output_dir

    @Slot(str, result=str)
    def select_output_dir(self, current: str) -> str:
        path = QFileDialog.getExistingDirectory(None, "选择输出目录", current)
        if path:
            self._output_dir = path
        return self._output_dir

    @Slot(str)
    def set_lyrics_output_dir(self, path: str):
        if os.path.isdir(path):
            self._lyrics_output_dir = path

    @Slot(result=str)
    def get_lyrics_output_dir(self) -> str:
        return self._lyrics_output_dir

    @Slot(str, result=str)
    def select_lyrics_output_dir(self, current: str) -> str:
        path = QFileDialog.getExistingDirectory(None, "选择歌词输出目录", current)
        if path:
            self._lyrics_output_dir = path
        return self._lyrics_output_dir

    # --- 历史记录 ---

    @Slot(result=str)
    def get_history(self) -> str:
        if not self._conversion_history:
            return "暂无转换记录"
        lines = []
        for h in self._conversion_history:
            lines.append(
                f"[{h['time']}] {h['status']}  {h['source']}  →  {h['output']}"
            )
        return "\n".join(lines)

    def _add_history(self, source: str, output: str, status: str):
        self._conversion_history.append({
            "time": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            "source": os.path.basename(source),
            "output": os.path.basename(output) if output else "-",
            "status": status,
        })

    # --- 内部回调 ---

    def _on_task_finished(self, task_id: str, result):
        if isinstance(result, AudioFile):
            for i, f in enumerate(self._files):
                if f.path == result.path or f.output_path == result.path:
                    self._files[i] = result
                    self._add_history(
                        f.path, result.output_path,
                        "成功" if result.status == AudioStatus.DONE else "失败"
                    )
                    break
            self.filesChanged.emit()
        elif isinstance(result, dict) and "title" in result:
            self._last_tags = result
            self.tagsLoaded.emit(result)

    def _on_task_failed(self, task_id: str, error: str):
        print(f"Task {task_id} failed: {error}")

    def _sync_player(self):
        self.playerStateChanged.emit()

    # --- QML 属性 ---

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

    @Property(int, notify=playerStateChanged)
    def selectedIndex(self) -> int:
        return self._selected_index


def main():
    app = QApplication(sys.argv)
    app.setOrganizationName("FastAppleMusic")
    app.setApplicationName("Fast Apple Music")

    icon_path = os.path.join(os.path.dirname(os.path.dirname(__file__)), "图标1.png")
    if os.path.exists(icon_path):
        app.setWindowIcon(QIcon(icon_path))

    bridge = AppBridge()

    qml_dir = os.path.join(os.path.dirname(os.path.dirname(__file__)), "qml")
    engine = QQmlApplicationEngine()
    context = engine.rootContext()
    context.setContextProperty("bridge", bridge)

    engine.load(QUrl.fromLocalFile(os.path.join(qml_dir, "main.qml")))

    roots = engine.rootObjects()
    if not roots:
        print("Failed to load QML")
        sys.exit(1)

    # Win32 修复：任务栏 + 圆角
    window = roots[0]
    from PySide6.QtCore import QTimer as QtTimer
    def _apply_fixes():
        h = window.winId()
        _fix_frameless_window(h)
        _apply_win11_rounded_corners(h)
    QtTimer.singleShot(100, _apply_fixes)

    sys.exit(app.exec())


if __name__ == "__main__":
    main()
