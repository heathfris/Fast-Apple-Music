"""音频播放控制器 — 封装 QtMultimedia"""
from PySide6.QtCore import QObject, Signal, Property, Slot
from PySide6.QtMultimedia import QMediaPlayer, QAudioOutput
from PySide6.QtCore import QUrl


class PlayerController(QObject):
    """音频播放控制器，暴露给 QML"""

    # 信号
    playingChanged = Signal()
    positionChanged = Signal(int)   # 播放位置变化（毫秒）
    durationChanged = Signal(int)   # 音频时长变化（毫秒）

    def __init__(self, parent=None):
        super().__init__(parent)
        self._player = QMediaPlayer()
        self._audio_output = QAudioOutput()
        self._player.setAudioOutput(self._audio_output)
        self._audio_output.setVolume(0.8)

        self._is_playing = False

        # 连接播放器原生信号
        self._player.playbackStateChanged.connect(self._on_state_changed)
        self._player.positionChanged.connect(self.positionChanged.emit)
        self._player.durationChanged.connect(self.durationChanged.emit)

    def _on_state_changed(self, state):
        self._is_playing = (state == QMediaPlayer.PlayingState)
        self.playingChanged.emit()

    # --- 属性 ---

    def isPlaying(self) -> bool:
        return self._is_playing

    playing = Property(bool, isPlaying, notify=playingChanged)

    # --- 槽 ---

    @Slot(str)
    def play_file(self, path: str):
        """播放指定文件"""
        self._player.setSource(QUrl.fromLocalFile(path))
        self._player.play()

    @Slot()
    def toggle_play(self):
        """播放/暂停切换"""
        if self._is_playing:
            self._player.pause()
        else:
            if self._player.source().isEmpty():
                return
            self._player.play()

    @Slot()
    def pause(self):
        self._player.pause()

    @Slot()
    def stop(self):
        self._player.stop()
        self._player.setSource(QUrl())  # 释放文件句柄

    def volume(self) -> float:
        return self._audio_output.volume()

    @Slot(float)
    def set_volume(self, vol: float):
        """设置音量 0.0-1.0"""
        self._audio_output.setVolume(vol)

    @Slot(int)
    def seek(self, ms: int):
        """跳转到指定位置（毫秒）"""
        self._player.setPosition(ms)

    def position(self) -> int:
        return self._player.position()

    def duration(self) -> int:
        return self._player.duration()
