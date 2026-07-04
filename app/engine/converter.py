"""音频转换引擎 — 核心业务逻辑"""
import os
from app.models.audiofile import AudioFile, AudioStatus
from app.utils.format_detect import (
    analyze_file, check_compliance, is_compliant,
    needs_conversion, recommend_target
)
from app.utils.ffmpeg_utils import (
    build_convert_command, run_ffmpeg, get_output_path, STRIP_TAGS
)


class ConversionEngine:
    """音频文件转换引擎"""

    def analyze(self, path: str) -> AudioFile:
        """分析单个文件，返回带完整属性的 AudioFile"""
        return analyze_file(path)

    def get_compliance_issues(self, af: AudioFile) -> list[str]:
        """获取文件不合规项"""
        return check_compliance(af)

    def is_already_compliant(self, af: AudioFile) -> bool:
        """文件是否已合规（不需要转换）"""
        return is_compliant(af)

    def needs_convert(self, af: AudioFile) -> bool:
        """文件是否需要格式转换"""
        return needs_conversion(af)

    def get_target_format(self, af: AudioFile) -> str:
        """推荐目标格式"""
        return recommend_target(af)

    def convert(
        self, af: AudioFile, output_dir: str,
        on_progress=None
    ) -> AudioFile:
        """
        转换单个文件。
        - 如果已合规：仅在需要时清除元数据（另存副本）
        - 如果需要转换：执行完整 FFmpeg 转换
        """
        af.status = AudioStatus.PROCESSING

        target_format = recommend_target(af)
        output_path = get_output_path(af.path, output_dir, target_format)

        needs_full = self.needs_convert(af)

        if needs_full:
            # 需要格式转换：FLAC→ALAC, WAV→ALAC, 24-bit→16-bit
            cmd = build_convert_command(af.path, output_path, target_format)
        else:
            # 已合规但仍需清除元数据标记
            cmd = ["ffmpeg", "-y", "-i", af.path, "-acodec", "copy"]
            for tag in STRIP_TAGS:
                cmd.extend(["-metadata", f"{tag}="])
            cmd.append(output_path)

        success, error = run_ffmpeg(cmd)

        if success:
            af.status = AudioStatus.DONE
            af.output_path = output_path
            af.error_message = ""
        else:
            af.status = AudioStatus.FAILED
            af.error_message = error

        return af
