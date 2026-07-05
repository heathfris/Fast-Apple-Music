"""app/models/audiofile.py 单元测试。

Muock 策略：无需 mock，纯数据类。
测试覆盖：AudioStatus 枚举 + AudioFile dataclass 全部字段和方法。
"""

import pytest

from app.models.audiofile import AudioFile, AudioStatus


# ============================================================================
# AudioStatus 枚举
# ============================================================================

class TestAudioStatus:
    """验证 AudioStatus 枚举的 5 个成员及其 .value。"""

    def test_enum_values(self):
        """所有枚举成员的值必须与规格一致。"""
        assert AudioStatus.PENDING.value == "pending"
        assert AudioStatus.PROCESSING.value == "processing"
        assert AudioStatus.DONE.value == "done"
        assert AudioStatus.FAILED.value == "failed"
        assert AudioStatus.TAGGED.value == "tagged"

    def test_enum_length(self):
        """确确认只有 5 个状态。"""
        assert len(AudioStatus) == 5


# ============================================================================
# AudioFile __post_init__
# ============================================================================

class TestAudioFilePostInit:
    """验证 __post_init__ 自动推导 filename 的逻辑。"""

    def test_filename_derived_from_path(self):
        """只提供 path 时，filename 自动取 basename。"""
        af = AudioFile(path="/music/test.mp3")
        assert af.filename == "test.mp3"

    def test_filename_already_set_preserved(self):
        """如果已显式指定 filename，不要覆盖。"""
        af = AudioFile(path="/music/test.mp3", filename="custom.flac")
        assert af.filename == "custom.flac"

    def test_filename_deep_path(self):
        """深层路径也能正确提取 basename。"""
        af = AudioFile(path="/a/b/c/song.wav")
        assert af.filename == "song.wav"

    def test_filename_windows_path(self):
        """Windows 风格路径（反斜杠）也能提取。"""
        af = AudioFile(path="C:\\Users\\me\\Music\\track.mp3")
        assert af.filename == "track.mp3"

    def test_filename_no_directory(self):
        """纯文件名（不带目录前缀）直接作为 filename。"""
        af = AudioFile(path="song.flac")
        assert af.filename == "song.flac"


# ============================================================================
# AudioFile 默认值
# ============================================================================

class TestAudioFileDefaults:
    """验证所有字段的默认值。"""

    def test_default_values_only_path(self):
        """只给 path 一个参数时的所有默认值。"""
        af = AudioFile(path="/music/test.mp3")
        assert af.filename == "test.mp3"  # __post_init__
        assert af.real_format == ""
        assert af.sample_rate == 0
        assert af.bit_depth == 0
        assert af.bitrate == 0
        assert af.duration == 0.0
        assert af.channels == 0
        assert af.file_size == 0
        assert af.status == AudioStatus.PENDING
        assert af.error_message == ""
        assert af.output_path == ""

    def test_all_fields_explicit(self):
        """所有字段显式传值，确保 dataclass 正确存储。"""
        af = AudioFile(
            path="/music/song.flac",
            filename="song.flac",
            real_format="flac",
            sample_rate=96000,
            bit_depth=24,
            bitrate=2304000,
            duration=245.6,
            channels=2,
            file_size=70_000_000,
            status=AudioStatus.TAGGED,
            error_message="some error",
            output_path="/out/song.m4a",
        )
        assert af.path == "/music/song.flac"
        assert af.real_format == "flac"
        assert af.sample_rate == 96000
        assert af.bit_depth == 24
        assert af.bitrate == 2_304_000
        assert af.duration == 245.6
        assert af.channels == 2
        assert af.file_size == 70_000_000
        assert af.status == AudioStatus.TAGGED
        assert af.error_message == "some error"
        assert af.output_path == "/out/song.m4a"


# ============================================================================
# status_icon()
# ============================================================================

class TestStatusIcon:
    """验证每种 AudioStatus 映射到正确的图标字符。"""

    def test_status_icon_each_status(self):
        """逐个验证 5 种状态的图标。"""
        cases = [
            (AudioStatus.PENDING, "○"),
            (AudioStatus.PROCESSING, "◌"),
            (AudioStatus.DONE, "✅"),
            (AudioStatus.FAILED, "⚠️"),
            (AudioStatus.TAGGED, "🏷️"),
        ]
        af = AudioFile(path="/x.mp3")
        for status, expected in cases:
            af.status = status
            assert af.status_icon() == expected, f"status={status}"

    def test_status_icon_pending_default(self):
        """新创建的 AudioFile 默认状态是 PENDING，图标为 ○。"""
        af = AudioFile(path="/x.mp3")
        assert af.status_icon() == "○"


# ============================================================================
# status_color()
# ============================================================================

class TestStatusColor:
    """验证每种 AudioStatus 映射到正确的十六进制颜色。"""

    def test_status_color_each_status(self):
        cases = [
            (AudioStatus.PENDING, "#8E8E93"),
            (AudioStatus.PROCESSING, "#007AFF"),
            (AudioStatus.DONE, "#34C759"),
            (AudioStatus.FAILED, "#FF3B30"),
            (AudioStatus.TAGGED, "#AF52DE"),
        ]
        af = AudioFile(path="/x.mp3")
        for status, expected in cases:
            af.status = status
            assert af.status_color() == expected, f"status={status}"

    def test_status_color_pending_default(self):
        """新创建 AudioFile 默认状态是 PENDING，对应灰色。"""
        af = AudioFile(path="/x.mp3")
        assert af.status_color() == "#8E8E93"


# ============================================================================
# duration_str()
# ============================================================================

class TestDurationStr:
    """验证 duration (float 秒) 格式化为 'm:ss' 字符串。"""

    def test_normal_duration(self):
        af = AudioFile(path="/x.mp3", duration=125.7)
        assert af.duration_str() == "2:05"

    def test_duration_zero(self):
        af = AudioFile(path="/x.mp3", duration=0)
        assert af.duration_str() == "0:00"

    def test_exactly_one_minute(self):
        af = AudioFile(path="/x.mp3", duration=60.0)
        assert af.duration_str() == "1:00"

    def test_less_than_one_minute(self):
        af = AudioFile(path="/x.mp3", duration=9.5)
        assert af.duration_str() == "0:09"

    def test_large_duration_over_one_hour(self):
        """时长超过 1 小时：4630s -> 77:10。"""
        af = AudioFile(path="/x.mp3", duration=4630.0)
        assert af.duration_str() == "77:10"

    def test_seconds_rounding_down(self):
        """小数秒向下取整：59.999 -> 59。"""
        af = AudioFile(path="/x.mp3", duration=65.99)
        assert af.duration_str() == "1:05"


# ============================================================================
# file_size_mb()
# ============================================================================

class TestFileSizeMb:
    """验证 file_size (int bytes) 格式化为 'X.XX MB' 字符串。"""

    def test_exactly_5mb(self):
        af = AudioFile(path="/x.mp3", file_size=5_242_880)
        assert af.file_size_mb() == "5.00 MB"

    def test_zero_bytes(self):
        af = AudioFile(path="/x.mp3", file_size=0)
        assert af.file_size_mb() == "0.00 MB"

    def test_one_byte(self):
        af = AudioFile(path="/x.mp3", file_size=1)
        assert af.file_size_mb() == "0.00 MB"

    def test_large_file(self):
        """约等于 200 MB。"""
        af = AudioFile(path="/x.mp3", file_size=209_715_200)
        assert af.file_size_mb() == "200.00 MB"

    def test_typical_mp3_size(self):
        """典型 MP3 大小 ~8 MB。"""
        af = AudioFile(path="/x.mp3", file_size=8_388_608)
        assert af.file_size_mb() == "8.00 MB"


# ============================================================================
# to_dict()
# ============================================================================

class TestToDict:
    """验证 to_dict() 返回的字典结构完整且包含所有计算字段。"""

    def test_contains_all_required_keys(self):
        af = AudioFile(path="/x.mp3")
        d = af.to_dict()

        required_keys = {
            "path", "filename", "real_format", "sample_rate",
            "bit_depth", "bitrate", "duration", "channels",
            "file_size", "status", "error_message", "output_path",
            "status_icon", "status_color", "duration_str", "file_size_mb",
        }
        assert set(d.keys()) == required_keys

    def test_status_is_value_not_enum(self):
        """status 序列化为 .value 字符串，不是 Enum 对象。"""
        af = AudioFile(path="/x.mp3", status=AudioStatus.FAILED)
        d = af.to_dict()
        assert d["status"] == "failed"
        assert not isinstance(d["status"], AudioStatus)

    def test_computed_fields_match_methods(self):
        """to_dict 里的计算字段必须和直接调用方法一致。"""
        af = AudioFile(
            path="/x.mp3",
            duration=135.0,
            file_size=1_048_576,
            status=AudioStatus.DONE,
        )
        d = af.to_dict()
        assert d["status_icon"] == af.status_icon()
        assert d["status_color"] == af.status_color()
        assert d["duration_str"] == af.duration_str()
        assert d["file_size_mb"] == af.file_size_mb()

    def test_all_fields_transferred(self):
        """完整对象的所有原始字段都准确传输到 dict。"""
        af = AudioFile(
            path="/a/b/test.flac",
            real_format="flac",
            sample_rate=48000,
            bit_depth=24,
            bitrate=921000,
            duration=210.3,
            channels=1,
            file_size=25_000_000,
            status=AudioStatus.PROCESSING,
            error_message="",
            output_path="/out/test.m4a",
        )
        d = af.to_dict()
        assert d["path"] == "/a/b/test.flac"
        assert d["real_format"] == "flac"
        assert d["sample_rate"] == 48000
        assert d["bit_depth"] == 24
        assert d["bitrate"] == 921000
        assert d["duration"] == 210.3
        assert d["channels"] == 1
        assert d["file_size"] == 25_000_000
        assert d["error_message"] == ""
        assert d["output_path"] == "/out/test.m4a"


# ============================================================================
# 边界条件 & 回归
# ============================================================================

class TestEdgeCases:
    """边界条件、空值和极端值的回归验证。"""

    def test_empty_path(self):
        """空 path 也能创建（虽然是坏数据，但不应崩溃）。"""
        af = AudioFile(path="")
        assert af.path == ""
        assert af.filename == ""

    def test_none_values_not_explode(self):
        """Dataclass 字段类型标注只是提示；传入不匹配值不应崩溃。"""
        af = AudioFile(path="/x.mp3", duration=-1.0, file_size=-1)
        assert af.duration == -1.0
        assert af.file_size == -1

    def test_equality(self):
        """相同内容的两个 AudioFile 应该相等（dataclass 默认 __eq__）。"""
        a = AudioFile(path="/x.mp3", duration=60.0)
        b = AudioFile(path="/x.mp3", duration=60.0)
        assert a == b

    def test_inequality(self):
        """不同内容的 AudioFile 不相等。"""
        a = AudioFile(path="/x.mp3")
        b = AudioFile(path="/y.flac")
        assert a != b
