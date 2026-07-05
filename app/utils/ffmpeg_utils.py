"""FFmpeg 命令构建辅助函数"""
import os
import subprocess
import shutil

# 需要从源文件清除的非标准元数据字段
STRIP_TAGS = [
    "comment",
    "information",
    "encoder",
    "major_brand",
    "minor_version",
    "compatible_brands",
]


def check_ffmpeg_available() -> bool:
    """检查 FFmpeg 是否在系统 PATH 中可用"""
    return shutil.which("ffmpeg") is not None


def build_convert_command(input_path: str, output_path: str, target_format: str) -> list[str]:
    """
    构建 FFmpeg 转换命令。
    输入可能是 FLAC/WAV/AIFF/ALAC24bit，输出为 Apple Music 兼容格式。
    """
    cmd = ["ffmpeg", "-y", "-i", input_path]

    # 音频编码器选择
    if target_format == "alac":
        codec = "alac"
        sample_fmt = "s16p"  # ALAC 编码器要求 planar 格式
    elif target_format == "mp3":
        codec = "libmp3lame"
        sample_fmt = None
    elif target_format == "aac":
        codec = "aac"
        sample_fmt = None
    else:
        codec = "alac"
        sample_fmt = "s16p"

    cmd.extend(["-acodec", codec])

    # 位深度：强制 16-bit
    if sample_fmt:
        cmd.extend(["-sample_fmt", sample_fmt])

    # 清除元数据标记
    for tag in STRIP_TAGS:
        cmd.extend(["-metadata", f"{tag}="])

    # 输出
    cmd.append(output_path)
    return cmd


def build_probe_command(path: str) -> list[str]:
    """构建 ffprobe 分析命令"""
    return [
        "ffprobe", "-v", "quiet", "-print_format", "json",
        "-show_format", "-show_streams", path
    ]


def run_ffmpeg(cmd: list[str], timeout: int = 300) -> tuple[bool, str]:
    """
    执行 FFmpeg 命令，返回 (成功与否, 错误信息)。
    timeout 默认 5 分钟。
    """
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            timeout=timeout,
        )
        if result.returncode == 0:
            return True, ""
        stderr = result.stderr
        if stderr:
            try:
                err_msg = stderr.decode("utf-8", errors="replace")
            except Exception:
                err_msg = str(stderr)
            # 返回完整错误信息的前端和后端（诊断关键信息通常在开头）
            if len(err_msg) <= 300:
                return False, err_msg
            return False, err_msg[:200] + "\n…\n" + err_msg[-100:]
        return False, f"Exit code: {result.returncode}"
    except subprocess.TimeoutExpired:
        return False, "转换超时（超过 5 分钟）"
    except FileNotFoundError:
        return False, "FFmpeg 未安装或不在 PATH 中"
    except Exception as e:
        return False, str(e)[:200]


def get_output_path(input_path: str, output_dir: str, target_format: str) -> str:
    """
    根据输入文件路径生成输出文件路径。
    同名文件通过父目录缩写来区分，避免覆盖。
    """
    ext_map = {"alac": ".m4a", "mp3": ".mp3", "aac": ".m4a"}
    ext = ext_map.get(target_format, ".m4a")
    basename = os.path.splitext(os.path.basename(input_path))[0]
    output_path = os.path.join(output_dir, f"{basename}{ext}")

    # 如果已有同名输出文件（不同源目录的同名文件），用父目录名区分
    if os.path.exists(output_path) and os.path.abspath(output_path) != os.path.abspath(input_path):
        parent = os.path.basename(os.path.dirname(input_path))
        if parent:
            output_path = os.path.join(output_dir, f"{basename}_{parent}{ext}")

    return output_path
