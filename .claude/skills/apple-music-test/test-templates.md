# Test Templates — 按模块的测试骨架

每个模块列出：mock 策略 + 必测用例 + 代码骨架。编写测试时直接复制骨架，填入断言即可。

---

## 1. test_audiofile.py — AudioFile 数据模型

**mock 策略：** 无需 mock，纯数据类。

```python
import pytest
from app.models.audiofile import AudioFile, AudioStatus

class TestAudioStatus:
    def test_enum_values(self):
        assert AudioStatus.PENDING.value == "pending"
        assert AudioStatus.DONE.value == "done"
        assert AudioStatus.FAILED.value == "failed"

class TestAudioFile:
    def test_default_values(self):
        af = AudioFile(path="/music/test.mp3")
        assert af.filename == "test.mp3"         # __post_init__ 自动填
        assert af.real_format == ""
        assert af.sample_rate == 0
        assert af.status == AudioStatus.PENDING

    def test_status_icon_each_status(self):
        """逐个验证 5 种状态的图标"""
        cases = [
            (AudioStatus.PENDING,    "○"),
            (AudioStatus.PROCESSING, "◌"),
            (AudioStatus.DONE,       "✅"),
            (AudioStatus.FAILED,     "⚠️"),
            (AudioStatus.TAGGED,     "🏷️"),
        ]
        af = AudioFile(path="/x.mp3")
        for status, expected in cases:
            af.status = status
            assert af.status_icon() == expected

    def test_status_color_each_status(self):
        cases = [
            (AudioStatus.PENDING,    "#8E8E93"),
            (AudioStatus.PROCESSING, "#007AFF"),
            (AudioStatus.DONE,       "#34C759"),
            (AudioStatus.FAILED,     "#FF3B30"),
            (AudioStatus.TAGGED,     "#AF52DE"),
        ]
        af = AudioFile(path="/x.mp3")
        for status, expected in cases:
            af.status = status
            assert af.status_color() == expected

    def test_duration_str_formatting(self):
        af = AudioFile(path="/x.mp3", duration=125.7)
        assert af.duration_str() == "2:05"

    def test_duration_str_zero(self):
        af = AudioFile(path="/x.mp3", duration=0)
        assert af.duration_str() == "0:00"

    def test_file_size_mb(self):
        af = AudioFile(path="/x.mp3", file_size=5242880)  # 5 MB
        assert af.file_size_mb() == "5.00 MB"

    def test_to_dict_contains_all_keys(self):
        af = AudioFile(path="/x.mp3", sample_rate=44100, bit_depth=16)
        d = af.to_dict()
        assert d["path"] == "/x.mp3"
        assert d["sample_rate"] == 44100
        assert "status_icon" in d
        assert "duration_str" in d

    def test_error_message_default(self):
        af = AudioFile(path="/x.mp3")
        assert af.error_message == ""
```

---

## 2. test_task.py — Task 数据模型

**mock 策略：** 无需 mock。

```python
import pytest
from app.models.task import Task, TaskType

class TestTaskType:
    def test_enum_values(self):
        assert TaskType.CONVERT.value == "convert"
        assert TaskType.READ_TAGS.value == "read_tags"
        assert TaskType.WRITE_TAGS.value == "write_tags"

class TestTask:
    def test_task_id_auto_generated(self):
        t = Task(task_id="", task_type=TaskType.CONVERT, file_path="/x.flac", kwargs={})
        assert len(t.task_id) == 8  # uuid4 hex 前 8 位

    def test_task_id_preserved_when_given(self):
        t = Task(task_id="abc123", task_type=TaskType.CONVERT, file_path="/x.flac", kwargs={})
        assert t.task_id == "abc123"
```

---

## 3. test_ffmpeg_utils.py — FFmpeg 命令构建与执行

**mock 策略：**
- `check_ffmpeg_available` → `patch("shutil.which")`
- `run_ffmpeg` → `patch("subprocess.run")`
- `build_convert_command` / `build_probe_command` / `get_output_path` → 纯函数，无需 mock

```python
import pytest
from unittest.mock import patch, MagicMock
from app.utils.ffmpeg_utils import (
    check_ffmpeg_available, build_convert_command,
    build_probe_command, run_ffmpeg, get_output_path, STRIP_TAGS
)

class TestCheckFfmpegAvailable:
    def test_available(self):
        with patch("app.utils.ffmpeg_utils.shutil.which", return_value="/usr/bin/ffmpeg"):
            assert check_ffmpeg_available() is True

    def test_not_available(self):
        with patch("app.utils.ffmpeg_utils.shutil.which", return_value=None):
            assert check_ffmpeg_available() is False

class TestBuildConvertCommand:
    def test_alac_target(self):
        cmd = build_convert_command("/in.flac", "/out.m4a", "alac")
        assert cmd[0] == "ffmpeg"
        assert "-acodec" in cmd and "alac" in cmd
        assert "-sample_fmt" in cmd and "s16p" in cmd
        assert cmd[-1] == "/out.m4a"

    def test_mp3_target(self):
        cmd = build_convert_command("/in.wav", "/out.mp3", "mp3")
        assert "libmp3lame" in cmd
        assert "-sample_fmt" not in cmd  # MP3 不设 sample_fmt

    def test_aac_target(self):
        cmd = build_convert_command("/in.wav", "/out.m4a", "aac")
        assert "aac" in cmd

    def test_strips_metadata_tags(self):
        cmd = build_convert_command("/in.flac", "/out.m4a", "alac")
        for tag in STRIP_TAGS:
            assert "-metadata" in cmd
            assert f"{tag}=" in cmd

    def test_unknown_format_defaults_to_alac(self):
        cmd = build_convert_command("/in.ogg", "/out.m4a", "ogg")
        assert "alac" in cmd

class TestBuildProbeCommand:
    def test_basic(self):
        cmd = build_probe_command("/test.flac")
        assert cmd[0] == "ffprobe"
        assert "-print_format" in cmd and "json" in cmd
        assert cmd[-1] == "/test.flac"

class TestRunFfmpeg:
    def test_success(self):
        with patch("app.utils.ffmpeg_utils.subprocess.run") as mock_run:
            mock_run.return_value.returncode = 0
            ok, err = run_ffmpeg(["ffmpeg", "-version"])
            assert ok is True
            assert err == ""

    def test_failure_with_stderr(self):
        with patch("app.utils.ffmpeg_utils.subprocess.run") as mock_run:
            mock_run.return_value.returncode = 1
            mock_run.return_value.stderr = "Error!".encode()
            ok, err = run_ffmpeg(["ffmpeg", "-i", "/bad.flac"])
            assert ok is False
            assert "Error!" in err

    def test_timeout(self):
        import subprocess
        with patch("app.utils.ffmpeg_utils.subprocess.run", side_effect=subprocess.TimeoutExpired(cmd=[], timeout=1)):
            ok, err = run_ffmpeg(["ffmpeg", "-i", "/big.flac"])
            assert ok is False
            assert "超时" in err

    def test_file_not_found(self):
        with patch("app.utils.ffmpeg_utils.subprocess.run", side_effect=FileNotFoundError()):
            ok, err = run_ffmpeg(["ffmpeg"])
            assert ok is False
            assert "未安装" in err

class TestGetOutputPath:
    def test_flac_to_alac(self):
        out = get_output_path("/music/song.flac", "/output", "alac")
        assert out.endswith(".m4a")
        assert "song" in out

    def test_mp3_stays_mp3(self):
        out = get_output_path("/music/song.mp3", "/output", "mp3")
        assert out.endswith(".mp3")
```

---

## 4. test_format_detect.py — 格式检测与合规检查

**mock 策略：**
- `analyze_file` → `patch("subprocess.run")` 控制 ffprobe 输出
- `check_compliance` / `is_compliant` / `needs_conversion` / `recommend_target` → 纯函数，构造 AudioFile 测试

```python
import json
import pytest
from unittest.mock import patch
from app.models.audiofile import AudioFile, AudioStatus
from app.utils.format_detect import (
    analyze_file, check_compliance, is_compliant,
    needs_conversion, recommend_target, SUPPORTED_FORMATS
)

# --- analyze_file（需 mock subprocess）---

def make_mock_run(stdout_json):
    """构造 mock subprocess.run 返回值"""
    m = MagicMock()
    m.returncode = 0
    m.stdout.decode.return_value = json.dumps(stdout_json)
    return m

def test_analyze_flac_file():
    with patch("app.utils.format_detect.subprocess.run") as mock_run:
        mock_run.return_value = make_mock_run({
            "streams": [{
                "codec_type": "audio", "codec_name": "flac",
                "sample_rate": "44100", "bits_per_raw_sample": 24,
                "channels": 2
            }],
            "format": {"bit_rate": "800000", "size": "18000000", "duration": "180.5"}
        })
        af = analyze_file("/test.flac")
        assert af.real_format == "flac"
        assert af.sample_rate == 44100
        assert af.bit_depth == 24
        assert af.status == AudioStatus.PENDING

def test_analyze_file_not_found():
    with patch("app.utils.format_detect.os.path.exists", return_value=False):
        af = analyze_file("/nonexistent.flac")
        assert af.status == AudioStatus.FAILED
        assert "不存在" in af.error_message

def test_analyze_ffprobe_error():
    with patch("app.utils.format_detect.subprocess.run") as mock_run:
        mock_run.return_value.returncode = 1
        mock_run.return_value.stderr.decode.return_value = "Invalid data"
        af = analyze_file("/bad.flac")
        assert af.status == AudioStatus.FAILED

# --- check_compliance（纯函数）---

def test_compliant_mp3():
    af = AudioFile(path="/x.mp3", real_format="mp3", bitrate=320000, bit_depth=16, sample_rate=44100)
    assert check_compliance(af) == []

def test_mp3_low_bitrate():
    af = AudioFile(path="/x.mp3", real_format="mp3", bitrate=64000)
    issues = check_compliance(af)
    assert any("比特率" in i for i in issues)

def test_24bit_not_allowed():
    af = AudioFile(path="/x.flac", real_format="flac", bit_depth=24, bitrate=800000)
    issues = check_compliance(af)
    assert any("位深度" in i for i in issues)

def test_oversized_file():
    af = AudioFile(path="/x.wav", real_format="wav", file_size=300 * 1048576)
    issues = check_compliance(af)
    assert any("200MB" in i for i in issues)

def test_too_long():
    af = AudioFile(path="/x.flac", real_format="flac", duration=8000)
    issues = check_compliance(af)
    assert any("2 小时" in i for i in issues)

def test_high_sample_rate():
    af = AudioFile(path="/x.flac", real_format="flac", sample_rate=96000)
    issues = check_compliance(af)
    assert any("48kHz" in i for i in issues)

# --- is_compliant ---

def test_is_compliant_mp3_320kbps():
    af = AudioFile(path="/x.mp3", real_format="mp3", bitrate=320000, bit_depth=16, sample_rate=44100)
    assert is_compliant(af) is True

def test_is_compliant_alac_16bit():
    af = AudioFile(path="/x.m4a", real_format="alac", bit_depth=16, sample_rate=44100)
    assert is_compliant(af) is True

def test_is_not_compliant_flac():
    af = AudioFile(path="/x.flac", real_format="flac", bit_depth=16)
    assert is_compliant(af) is False

# --- needs_conversion ---

def test_flac_needs_conversion():
    af = AudioFile(path="/x.flac", real_format="flac")
    assert needs_conversion(af) is True

def test_mp3_does_not_need_conversion():
    af = AudioFile(path="/x.mp3", real_format="mp3", bit_depth=16)
    assert needs_conversion(af) is False

# --- recommend_target ---

def test_recommend_flac_to_alac():
    af = AudioFile(path="/x.flac", real_format="flac")
    assert recommend_target(af) == "alac"

def test_recommend_mp3_stays_mp3():
    af = AudioFile(path="/x.mp3", real_format="mp3")
    assert recommend_target(af) == "mp3"

def test_recommend_unknown_to_alac():
    af = AudioFile(path="/x.ogg", real_format="ogg")
    assert recommend_target(af) == "alac"
```

---

## 5. test_converter.py — 转换引擎

**mock 策略：** mock subprocess（ffmpeg），用假的 ffprobe 输出构造 AudioFile。

```python
import pytest
from unittest.mock import patch, MagicMock
from app.models.audiofile import AudioFile, AudioStatus
from app.engine.converter import ConversionEngine

@pytest.fixture
def engine():
    return ConversionEngine()

class TestConversionEngine:
    def test_analyze_delegates(self, engine):
        """analyze() 应委托给 format_detect.analyze_file"""
        with patch("app.engine.converter.analyze_file") as mock_analyze:
            mock_analyze.return_value = AudioFile(path="/x.mp3", real_format="mp3")
            result = engine.analyze("/x.mp3")
            assert result.real_format == "mp3"

    def test_convert_flac_to_alac(self, engine):
        af = AudioFile(path="/x.flac", real_format="flac",
                       sample_rate=44100, bit_depth=16, bitrate=800000)
        with patch("app.engine.converter.run_ffmpeg", return_value=(True, "")):
            result = engine.convert(af, "/output")
            assert result.status == AudioStatus.DONE
            assert result.output_path  # 非空

    def test_convert_failure(self, engine):
        af = AudioFile(path="/x.flac", real_format="flac", bit_depth=16)
        with patch("app.engine.converter.run_ffmpeg", return_value=(False, "codec error")):
            result = engine.convert(af, "/output")
            assert result.status == AudioStatus.FAILED
            assert "codec error" in result.error_message

    def test_compliant_file_metadata_strip_only(self, engine):
        """已合规文件只做元数据清除，不改编码"""
        af = AudioFile(path="/x.mp3", real_format="mp3",
                       bitrate=320000, bit_depth=16, sample_rate=44100)
        with patch("app.engine.converter.run_ffmpeg", return_value=(True, "")) as mock_run:
            result = engine.convert(af, "/output")
            assert result.status == AudioStatus.DONE
            # 验证命令用了 copy codec（不是重新编码）
            cmd = mock_run.call_args[0][0]
            assert "-acodec" in cmd and "copy" in cmd
```

---

## 6. test_reader.py — 标签读取

**mock 策略：** `patch("mutagen.File")` 返回三种不同类型的 mock 对象。

```python
import pytest
from unittest.mock import patch, MagicMock
from app.metadata.reader import read_tags, _empty_tags

class TestReadTags:
    def test_file_not_exist(self):
        with patch("app.metadata.reader.os.path.exists", return_value=False):
            tags = read_tags("/nonexistent.mp3")
            assert tags["title"] == ""
            assert tags["artist"] == ""

    def test_read_mp3_tags(self):
        mock_id3 = {
            "TIT2": MagicMock(text=["Test Title"]),
            "TPE1": MagicMock(text=["Test Artist"]),
            "TALB": MagicMock(text=["Test Album"]),
        }
        mock_mp3 = MagicMock()
        mock_mp3.tags = mock_id3
        with patch("app.metadata.reader.MutagenFile", return_value=mock_mp3):
            with patch("app.metadata.reader.os.path.exists", return_value=True):
                tags = read_tags("/test.mp3")
                assert tags["title"] == "Test Title"
                assert tags["artist"] == "Test Artist"

    def test_empty_tags_structure(self):
        t = _empty_tags()
        assert set(t.keys()) == {
            "title", "artist", "album", "album_artist",
            "composer", "year", "genre", "cover_data"
        }
        assert t["cover_data"] is None
```

---

## 7. test_writer.py — 标签写入

**mock 策略：** `patch("mutagen.File")` 模拟三种格式的写入路径。

```python
import pytest
from unittest.mock import patch, MagicMock
from app.metadata.writer import write_tags

class TestWriteTags:
    def test_file_not_found(self):
        with patch("app.metadata.writer.os.path.exists", return_value=False):
            with pytest.raises(FileNotFoundError):
                write_tags("/nonexistent.mp3", {"title": "X"})

    def test_unsupported_format(self):
        mock_audio = None  # MutagenFile 返回 None
        with patch("app.metadata.writer.os.path.exists", return_value=True):
            with patch("app.metadata.writer.MutagenFile", return_value=mock_audio):
                with pytest.raises(ValueError, match="不支持"):
                    write_tags("/test.unknown", {"title": "X"})

    def test_write_mp3_tags(self):
        mock_mp3 = MagicMock()
        mock_mp3.tags = None  # 触发 ID3() 创建
        with patch("app.metadata.writer.os.path.exists", return_value=True):
            with patch("app.metadata.writer.MutagenFile", return_value=mock_mp3):
                write_tags("/test.mp3", {
                    "title": "New Title",
                    "artist": "New Artist",
                    "year": "2024"
                })
                mock_mp3.save.assert_called_once()
```

---

## 8. test_worker.py — 异步任务队列

**mock 策略：** mock QThread 的 start/run 行为，只验证队列操作和信号连接。可以选择 mock `ConversionEngine` 避免真实 ffprobe 调用。

```python
import pytest
from unittest.mock import patch, MagicMock
from app.models.task import Task, TaskType
from app.engine.worker import TaskWorker

class TestTaskWorker:
    def test_add_task_increments_pending(self):
        """只验证添加任务后内部队列大小，不启动线程"""
        # 不调用 start()，只测队列逻辑
        w = TaskWorker()
        assert w._pending_count == 0
        t = Task(task_id="t1", task_type=TaskType.CONVERT,
                 file_path="/x.flac", kwargs={})
        w.add_task(t)
        assert w._pending_count == 1

    def test_add_tasks_batch(self):
        w = TaskWorker()
        tasks = [
            Task(task_id=f"t{i}", task_type=TaskType.CONVERT,
                 file_path=f"/x{i}.flac", kwargs={})
            for i in range(3)
        ]
        w.add_tasks(tasks)
        assert w._pending_count == 3

    def test_cancel_all_clears_queue(self):
        w = TaskWorker()
        t = Task(task_id="t1", task_type=TaskType.CONVERT,
                 file_path="/x.flac", kwargs={})
        w.add_task(t)
        w.cancel_all()
        assert w._pending_count == 0  # 注意：cancel_all 不重置 pending_count
        # 队列应为空
        assert w._queue.empty()

    def test_signal_connections_exist(self):
        """验证 Worker 有正确的 Qt 信号定义"""
        w = TaskWorker()
        assert hasattr(w, 'task_started')
        assert hasattr(w, 'task_progress')
        assert hasattr(w, 'task_finished')
        assert hasattr(w, 'task_failed')
        assert hasattr(w, 'all_done')
```

---

## conftest.py — 共享 Fixtures

```python
import pytest
import json

@pytest.fixture
def sample_ffprobe_json():
    """标准 16-bit/44.1kHz FLAC 的 ffprobe 输出"""
    return json.dumps({
        "streams": [{
            "codec_type": "audio",
            "codec_name": "flac",
            "sample_rate": "44100",
            "bits_per_raw_sample": 16,
            "channels": 2,
            "duration": "180.5"
        }],
        "format": {
            "bit_rate": "800000",
            "size": "18000000",
            "duration": "180.5"
        }
    })

@pytest.fixture
def sample_tags():
    return {
        "title": "Test Song",
        "artist": "Test Artist",
        "album": "Test Album",
        "album_artist": "Test AA",
        "composer": "Test Composer",
        "year": "2024",
        "genre": "Pop",
        "cover_data": None
    }

@pytest.fixture
def compliant_mp3():
    from app.models.audiofile import AudioFile
    return AudioFile(
        path="/test.mp3", real_format="mp3",
        bitrate=320000, bit_depth=16, sample_rate=44100,
        duration=200.0, file_size=5_000_000
    )

@pytest.fixture
def noncompliant_flac():
    from app.models.audiofile import AudioFile
    return AudioFile(
        path="/test.flac", real_format="flac",
        bit_depth=24, sample_rate=44100,
        bitrate=800000, duration=180.0
    )
```
