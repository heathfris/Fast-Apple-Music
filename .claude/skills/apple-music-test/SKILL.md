---
name: apple-music-test
description: Use when asked to create unit tests, run tests, generate test coverage reports, or verify test results for the Fast Apple Music project. Triggers on "test", "单元测试", "pytest", "coverage", "测试报告", "run tests", "check coverage", or any testing-related request in this project.
---

# AppleMusicTest — 项目单元测试

将项目 Python 代码拆分为可测试的"纯逻辑"与"外部依赖"，用 pytest + unittest.mock 编写并运行单元测试，最后输出一份包含通过/失败明细和覆盖率百分比的测试报告。

## 测试框架与工具

| 工具 | 用途 |
|------|------|
| **pytest** | 测试运行器 + 断言框架 |
| **pytest-cov** | 覆盖率收集（依赖 coverage.py） |
| **unittest.mock** | 标准库 mock 工具，替代 ffmpeg/ffprobe/Qt |

**安装（一次性）：**
```bash
pip install pytest pytest-cov
```

## 项目可测试模块一览

```
app/
├── utils/
│   ├── ffmpeg_utils.py      ← 纯函数：命令构建、路径生成、subprocess 封装
│   └── format_detect.py     ← 纯函数：合规检查、格式推荐（依赖 ffprobe）
├── models/
│   ├── audiofile.py         ← 纯数据：dataclass、枚举、格式化方法
│   └── task.py              ← 纯数据：dataclass、枚举
├── engine/
│   ├── converter.py         ← 业务编排：拼装 analyze + convert 流程
│   └── worker.py            ← Qt 集成：QThread 信号 → 仅做结构验证
├── metadata/
│   ├── reader.py            ← mutagen 封装：读标签（需要真实文件或 mock）
│   └── writer.py            ← mutagen 封装：写标签（需要真实文件或 mock）
└── main.py                  ← 应用入口：不做单元测试
```

**测试优先级：** `utils/` > `models/` > `metadata/` > `engine/converter.py` > `engine/worker.py`

## 测试执行命令

```bash
# 基础运行（在项目根目录）
pytest tests/ -v

# 带覆盖率 → 终端摘要
pytest tests/ -v --cov=app --cov-report=term-missing

# 生成 HTML 测试报告（可在浏览器打开）
pytest tests/ -v --cov=app --cov-report=html --cov-report=term-missing

# 只跑某个模块
pytest tests/test_ffmpeg_utils.py -v

# 按关键词过滤
pytest tests/ -v -k "compliance"
```

## 标准工作流

### 1. 创建测试

分析目标模块，识别所有输入→输出分支，为每个分支生成一个 `def test_<场景>()`。测试文件放入 `tests/` 目录，命名规则：`test_<模块名>.py`。

**模块对应的测试文件：**

| 源文件 | 测试文件 |
|--------|---------|
| `app/utils/ffmpeg_utils.py` | `tests/test_ffmpeg_utils.py` |
| `app/utils/format_detect.py` | `tests/test_format_detect.py` |
| `app/models/audiofile.py` | `tests/test_audiofile.py` |
| `app/models/task.py` | `tests/test_task.py` |
| `app/engine/converter.py` | `tests/test_converter.py` |
| `app/metadata/reader.py` | `tests/test_reader.py` |
| `app/metadata/writer.py` | `tests/test_writer.py` |
| `app/engine/worker.py` | `tests/test_worker.py` |

详细测试模板见 [test-templates.md](test-templates.md) — 包含每个模块的 mock 策略和测试用例骨架。

### 2. 执行测试

```bash
pytest tests/ -v --cov=app --cov-report=term-missing --tb=short
```

成功标准：全部 PASSED，无 FAILED/ERROR。

### 3. 生成测试报告

报告含三部分：

**A. 测试结果摘要**
```
=== 测试报告 ===
总用例数: N
✅ 通过:   X
❌ 失败:   Y
💥 错误:   Z
⏭️  跳过:   W
总耗时:    X.XXs
```

**B. 覆盖率表**
```
模块                          覆盖率
app/utils/ffmpeg_utils.py     95%
app/utils/format_detect.py    92%
app/models/audiofile.py      100%
...
TOTAL                         87%
```

**C. 失败用例明细**（如有）
```
FAILED tests/test_format_detect.py::test_check_compliance_mp3_low_bitrate
  AssertionError: 期望 '比特率低于 96kbps' 在 issue 列表中，但未找到
```

使用 `--tb=short` 获取紧凑的失败信息，`--tb=long` 看完整堆栈。

## 模块分策略

### 纯逻辑（无需 mock）：`audiofile.py`、`task.py`、`format_detect.py` 的 check/recommend 函数

直接构造输入数据，断言返回值。最快，覆盖面最广。

```python
from app.models.audiofile import AudioFile, AudioStatus

def test_audiofile_status_icon():
    af = AudioFile(path="/test.mp3")
    af.status = AudioStatus.DONE
    assert af.status_icon() == "✅"
```

### subprocess 封装（需 mock）：`ffmpeg_utils.py`、`format_detect.py` 的 analyze_file

用 `unittest.mock.patch` 替换 `subprocess.run`，控制返回码和 stdout/stderr。

```python
from unittest.mock import patch, MagicMock
from app.utils.ffmpeg_utils import run_ffmpeg

def test_run_ffmpeg_success():
    with patch("app.utils.ffmpeg_utils.subprocess.run") as mock_run:
        mock_run.return_value.returncode = 0
        ok, err = run_ffmpeg(["ffmpeg", "-version"])
        assert ok is True
        assert err == ""
```

### 文件 I/O / mutagen（需真实文件或 mock）：`reader.py`、`writer.py`

策略：创建临时音频文件（pytest 的 `tmp_path` fixture），或用 `patch("mutagen.File")` mock。

### Qt / QThread（结构验证）：`worker.py`

不真正启动 QApplication，验证 Worker 的 `add_task`、`cancel_all` 队列行为和信号连接模式。

## 测试目录结构

```
tests/
├── __init__.py                  # 空文件，让 pytest 正确发现包
├── conftest.py                  # 共享 fixtures（示例音频数据、mock ffprobe 输出等）
├── test_ffmpeg_utils.py
├── test_format_detect.py
├── test_audiofile.py
├── test_task.py
├── test_converter.py
├── test_reader.py
├── test_writer.py
└── test_worker.py
```

`conftest.py` 放所有测试文件共享的 fixtures：
```python
import pytest
import json

@pytest.fixture
def sample_ffprobe_output():
    """模拟 ffprobe 对 16-bit/44.1kHz FLAC 文件的输出"""
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
```

## 常见陷阱

| 陷阱 | 表现 | 修复 |
|------|------|------|
| 没 mock subprocess | 测试依赖本机 ffmpeg 安装 | `patch("路径.to.subprocess.run")` |
| mock 路径错了 | mock 不生效 | mock 的路径必须是**被测模块内**的 import 路径，不是定义模块的路径 |
| ffprobe JSON 格式不对 | analyze_file 返回 FAILED | 确保 mock 的 stdout 是有效 JSON，含 `streams` 和 `format` 键 |
| AudioFile dataclass 默认值 | filename 自动填了 basename | 传 `path="/test.mp3"` 时 filename 自动为 `"test.mp3"` |
| QApplication 未初始化 | Qt 模块导入崩溃 | worker 测试中 mock QThread 或确保 `QApplication()` 已在 conftest 中初始化 |

## 报告输出位置

- HTML 覆盖率报告：`htmlcov/index.html`（用浏览器打开可逐行查看覆盖情况）
- 终端摘要：直接显示在 pytest 输出中
- 如需 JSON 报告：加 `--cov-report=json` 生成 `coverage.json`<｜end▁of▁thinking｜>现在创建测试模板参考文件，包含每个模块的具体测试策略和代码骨架。

<｜｜DSML｜｜tool_calls>
<｜｜DSML｜｜invoke name="TodoWrite">
<｜｜DSML｜｜parameter name="todos" string="false">[{"activeForm": "Creating AppleMusicTest skill SKILL.md", "content": "Create AppleMusicTest skill SKILL.md", "status": "completed"}, {"activeForm": "Creating test templates reference file", "content": "Create test templates reference file", "status": "in_progress"}]