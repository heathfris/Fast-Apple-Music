"""音频格式检测与 Apple Music 合规检查"""
import subprocess
import json
import os
from typing import Optional
from app.models.audiofile import AudioFile, AudioStatus


def analyze_file(path: str) -> AudioFile:
    """用 ffprobe 分析音频文件，返回 AudioFile 对象"""
    if not os.path.exists(path):
        af = AudioFile(path=path)
        af.status = AudioStatus.FAILED
        af.error_message = "文件不存在"
        return af

    cmd = [
        "ffprobe", "-v", "quiet", "-print_format", "json",
        "-show_format", "-show_streams", path
    ]
    try:
        result = subprocess.run(cmd, capture_output=True, timeout=15)
        if result.returncode != 0:
            stderr_text = result.stderr.decode("utf-8", errors="replace")[:100]
            af = AudioFile(path=path)
            af.status = AudioStatus.FAILED
            af.error_message = f"ffprobe 无法解析: {stderr_text}"
            return af

        stdout_text = result.stdout.decode("utf-8", errors="replace")
        data = json.loads(stdout_text)
    except (subprocess.TimeoutExpired, json.JSONDecodeError, FileNotFoundError) as e:
        af = AudioFile(path=path)
        af.status = AudioStatus.FAILED
        af.error_message = f"文件分析失败: {str(e)[:100]}"
        return af

    streams = data.get("streams", [])
    fmt = data.get("format", {})

    # 取第一条音频流
    audio_stream = None
    for s in streams:
        if s.get("codec_type") == "audio":
            audio_stream = s
            break
    if not audio_stream:
        af = AudioFile(path=path)
        af.status = AudioStatus.FAILED
        af.error_message = "文件中未找到音频流"
        return af

    codec = audio_stream.get("codec_name", "unknown")
    raw_bits = audio_stream.get("bits_per_raw_sample")
    bits = raw_bits if raw_bits else audio_stream.get("bits_per_sample", 0)
    bitrate_raw = int(fmt.get("bit_rate", 0) or 0)
    duration_raw = float(fmt.get("duration", 0) or 0)

    af = AudioFile(
        path=path,
        real_format=codec,
        sample_rate=int(audio_stream.get("sample_rate", 0) or 0),
        bit_depth=int(bits or 0),
        bitrate=bitrate_raw,
        duration=duration_raw,
        channels=int(audio_stream.get("channels", 0) or 0),
        file_size=int(fmt.get("size", 0) or 0),
        status=AudioStatus.PENDING,
    )
    return af


# Apple Music 支持的格式
SUPPORTED_FORMATS = {"mp3", "aac", "alac", "wav", "aiff", "flac"}
# 需要容器转换的格式（FLAC → ALAC, WAV → ALAC, AIFF → ALAC）
NEEDS_CONTAINER_SWITCH = {"flac", "wav", "aiff"}


def check_compliance(af: AudioFile) -> list[str]:
    """检查 AudioFile 是否符合 Apple Music 要求，返回不合规项列表"""
    issues = []

    if af.real_format not in SUPPORTED_FORMATS:
        issues.append(f"不支持的格式: {af.real_format}")

    if af.file_size > 200 * 1048576:
        issues.append("文件超过 200MB 限制")

    if af.duration > 7200:  # 2 hours
        issues.append("时长超过 2 小时限制")

    if af.bitrate > 0 and af.bitrate < 96000:
        issues.append("比特率低于 96kbps")

    if af.bit_depth > 16:
        issues.append(f"{af.bit_depth}-bit 位深度（需降至 16-bit）")

    if af.sample_rate > 48000:
        issues.append(f"采样率 {af.sample_rate}Hz 超限（需 ≤48kHz）")

    return issues


def is_compliant(af: AudioFile) -> bool:
    """是否已经可以直接上传（无需转换）"""
    if af.real_format in ("mp3", "aac") and af.bit_depth <= 16 and af.sample_rate <= 48000:
        if af.bitrate == 0 or af.bitrate >= 96000:
            return True
    if af.real_format == "alac" and af.bit_depth <= 16 and af.sample_rate <= 48000:
        return True
    return False


def needs_conversion(af: AudioFile) -> bool:
    """是否需要格式转换"""
    return af.real_format in NEEDS_CONTAINER_SWITCH or af.bit_depth > 16


def recommend_target(af: AudioFile) -> str:
    """推荐目标格式"""
    if af.real_format in NEEDS_CONTAINER_SWITCH:
        return "alac"
    if af.real_format == "alac" and af.bit_depth > 16:
        return "alac"  # 保持 ALAC，仅降位深度
    if af.real_format in ("mp3", "aac"):
        return af.real_format  # 原样保留
    # 其他不支持格式
    return "alac"
