from dataclasses import dataclass, field
from enum import Enum


class AudioStatus(Enum):
    PENDING = "pending"       # ○ 待处理
    PROCESSING = "processing" # ◌ 处理中
    DONE = "done"             # ✅ 完成
    FAILED = "failed"         # ⚠️ 失败
    TAGGED = "tagged"         # 🏷️ 已标签


@dataclass
class AudioFile:
    path: str                        # 源文件绝对路径
    filename: str = ""               # 文件名（不含路径）
    real_format: str = ""            # 实际编码格式 flac/wav/mp3/alac/aac/...
    sample_rate: int = 0             # 采样率 Hz
    bit_depth: int = 0               # 位深度
    bitrate: int = 0                 # 比特率 bps
    duration: float = 0.0            # 时长 秒
    channels: int = 0                # 声道数
    file_size: int = 0              # 文件大小 bytes
    status: AudioStatus = AudioStatus.PENDING
    error_message: str = ""          # 失败原因
    output_path: str = ""            # 转换后输出路径

    def __post_init__(self):
        import os
        if not self.filename:
            self.filename = os.path.basename(self.path)

    def status_icon(self) -> str:
        """返回状态图标文本，QML 侧根据此值渲染"""
        icons = {
            AudioStatus.PENDING:    "●",
            AudioStatus.PROCESSING: "●",
            AudioStatus.DONE:       "●",
            AudioStatus.FAILED:     "●",
            AudioStatus.TAGGED:     "●",
        }
        return icons.get(self.status, "●")

    def status_color(self) -> str:
        """返回状态对应颜色"""
        colors = {
            AudioStatus.PENDING:    "#8E8E93",
            AudioStatus.PROCESSING: "#007AFF",
            AudioStatus.DONE:       "#34C759",
            AudioStatus.FAILED:     "#FF3B30",
            AudioStatus.TAGGED:     "#AF52DE",
        }
        return colors.get(self.status, "#8E8E93")

    def duration_str(self) -> str:
        """时长格式化为 mm:ss"""
        m = int(self.duration // 60)
        s = int(self.duration % 60)
        return f"{m}:{s:02d}"

    def file_size_mb(self) -> str:
        """文件大小格式化为 MB"""
        return f"{self.file_size / 1048576:.2f} MB"

    def to_dict(self) -> dict:
        return {
            "path": self.path,
            "filename": self.filename,
            "real_format": self.real_format,
            "sample_rate": self.sample_rate,
            "bit_depth": self.bit_depth,
            "bitrate": self.bitrate,
            "duration": self.duration,
            "channels": self.channels,
            "file_size": self.file_size,
            "status": self.status.value,
            "error_message": self.error_message,
            "output_path": self.output_path,
            "status_icon": self.status_icon(),
            "status_color": self.status_color(),
            "duration_str": self.duration_str(),
            "file_size_mb": self.file_size_mb(),
        }
