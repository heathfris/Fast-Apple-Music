"""Fast Apple Music — 共享测试 fixtures 和 PyTest 配置。

本项目使用纯函数 + unittest.mock 策略：
- 不依赖真实 ffmpeg/ffprobe 安装
- 不依赖真实音频文件
- 不依赖 QApplication（Worker 测试只验证结构）
"""

import json

import pytest


# ---------------------------------------------------------------------------
# AudioFile / AudioStatus 共享 fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def sample_tags():
    """标准标签字典，用于 reader/writer 测试。"""
    return {
        "title": "Test Song",
        "artist": "Test Artist",
        "album": "Test Album",
        "album_artist": "Test AA",
        "composer": "Test Composer",
        "year": "2024",
        "genre": "Pop",
        "cover_data": None,
    }


# ---------------------------------------------------------------------------
# ffprobe 模拟输出
# ---------------------------------------------------------------------------

@pytest.fixture
def sample_ffprobe_json():
    """标准 16-bit / 44.1 kHz FLAC 文件的 ffprobe JSON 输出字符串。"""
    return json.dumps(
        {
            "streams": [
                {
                    "codec_type": "audio",
                    "codec_name": "flac",
                    "sample_rate": "44100",
                    "bits_per_raw_sample": 16,
                    "channels": 2,
                    "duration": "180.5",
                }
            ],
            "format": {
                "bit_rate": "800000",
                "size": "18000000",
                "duration": "180.5",
            },
        }
    )


# ---------------------------------------------------------------------------
# AudioFile 预制实例（合规 / 不合规）
# ---------------------------------------------------------------------------

@pytest.fixture
def compliant_mp3():
    """一个完全合规的 MP3 文件（16bit / 44.1kHz / 320kbps）。"""
    from app.models.audiofile import AudioFile

    return AudioFile(
        path="/test.mp3",
        real_format="mp3",
        bitrate=320000,
        bit_depth=16,
        sample_rate=44100,
        duration=200.0,
        file_size=5_000_000,
    )


@pytest.fixture
def noncompliant_flac():
    """一个不合规的 FLAC 文件（24bit，需要转换）。"""
    from app.models.audiofile import AudioFile

    return AudioFile(
        path="/test.flac",
        real_format="flac",
        bit_depth=24,
        sample_rate=44100,
        bitrate=800000,
        duration=180.0,
    )
