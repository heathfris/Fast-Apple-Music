# Apple Music 音频预处理工具 — 设计文档

> 日期：2026-07-04
> 状态：已确认，待实施

---

## 一、项目概述

### 1.1 背景

Apple Music 允许用户上传本地音频到 iCloud 音乐库，但有严格的格式和技术限制：
- 不支持 FLAC、WMA 等格式
- 不支持 24-bit 位深度
- 音频文件中可能残留来源平台标记（如抖音 `com.bytedance.info`）
- 上传前需要检查比特率（≥96kbps）、时长（≤2h）、文件大小（≤200MB）

普通用户在上传前需要手动用多个工具进行格式转换、参数检查、元数据清理，流程繁琐且容易出错。

### 1.2 目标

开发一个跨平台桌面工具，让用户只需**拖入音频文件 → 点击转换**即可获得符合 Apple Music 规范的、纯净的音频文件。同时提供试听、元数据编辑等辅助功能。

### 1.3 平台

- Windows（主要）
- macOS（兼容）

---

## 二、核心功能（v1）

### 2.1 自动导入 + 格式检测 + 转换

**用户操作**：拖入或选择音频文件

**自动完成**：
1. 检测实际格式（不依赖扩展名）和属性（采样率、位深度、比特率、时长、声道、文件大小）
2. 根据分析结果自动选择最佳目标格式：

| 源格式 | 目标格式 | 转换内容 |
|--------|----------|----------|
| FLAC | ALAC (.m4a) | 容器转换（无损→无损），24-bit→16-bit 如需 |
| WAV | ALAC (.m4a) | 同上 |
| AIFF | ALAC (.m4a) | 同上 |
| ALAC 24-bit | 保持 ALAC，降为 16-bit | 仅降位深度 |
| MP3 (≥96kbps) | MP3（原样保留） | 不清除音频数据，仅清除元数据标记 |
| AAC (≥96kbps) | AAC（原样保留） | 同上 |
| WMA / 其他不支持 | ALAC (.m4a) | 全转换 |

3. 清除所有来源平台残留标记（`comment`、`information`、旧 `encoder` 等非标准字段）
4. 保存到用户指定目录（默认：源文件同目录 / 桌面）

### 2.2 批量处理

- 支持同时导入多个文件
- 批量转换：全选/多选后一键处理
- 异步执行：后台处理，不卡 UI
- 进度反馈：底部状态栏显示「5/12 首 · 45%」
- 每个文件独立状态：○ 待处理 / ◌ 处理中 / ✅ 完成 / ⚠️ 失败
- 失败文件显示具体原因（格式不支持、文件过大、时长超限等）

### 2.3 实时试听

- 双击文件列表中的歌曲开始播放
- 底部统一播放条：播放/暂停、进度拖拽、上一首/下一首
- 可试听原文件（导入后）和处理后文件（转换后）
- 基于 QtMultimedia，支持常见格式解码

### 2.4 元数据编辑

- 点击文件列表中的歌曲，右侧面板加载并显示现有标签
- 支持编辑字段：
  - 专辑封面（拖入图片，自动缩放嵌入）
  - 曲名
  - 艺人
  - 专辑
  - 专辑艺人
  - 作曲
  - 年份
  - 流派
- 点击「保存标签」写入文件
- 底层使用 mutagen 库处理不同格式的标签标准
- 支持批量填充：选中多首后，可一键设置相同的「艺人」「专辑」「封面」等

---

## 三、不包含的功能（留待后续版本）

| 功能 | 版本计划 |
|------|----------|
| A1 去除杂声/降噪 | v2 — 需集成 FFmpeg 降噪滤波器 |
| A2 分离人声和伴奏 | v2 — 需集成 Demucs AI 模型 |
| A3 调节人声/伴奏音量 | v2 — 依赖 A2 |
| A6 歌词识别 | v2 — 在线 API + Whisper 降级方案 |
| 实时参数调节预览 | v2 — 当前 v1 只能播放，不能实时调参听效果 |

---

## 四、UI 设计

### 4.1 设计语言

仿 Apple Music 风格：
- 深色背景（`#1A1A1A` 主背景，`#2C2C2E` 卡片）
- 毛玻璃半透明侧边栏（`rgba(44,44,46,0.85)` + `backdrop-filter: blur(20px)`）
- 大圆角（12px 卡片，8px 按钮）
- 红色强调色（`#FA2D48`，Apple Music 标志红）
- 字体系列：SF Pro Display（macOS）/ Segoe UI（Windows）
- 图标：SF Symbols 风格线性图标

### 4.2 布局（三栏）

```
┌── 标题栏 ───────────────────────────────────────────┐
│  🎵 Fast Apple Music                    ─ □ ✕       │
├──────────┬──────────────────────┬───────────────────┤
│ 侧边栏    │    主工作区            │   元数据面板       │
│ (180px)  │                      │   (280px)         │
│          │  ┌────────────────┐  │  ┌─────────────┐  │
│ 📁 导入  │  │  ☁ songA.flac  │  │  │  专辑封面    │  │
│ 🔊 试听  │  │  ☁ songB.wav   │  │  │ [拖入图片]   │  │
│ 🏷️ 标签  │  │  ☁ songC.mp3   │  │  │             │  │
│ ⚙️ 设置  │  │  ☁ songD.flac  │  │  └─────────────┘  │
│          │  │  ...           │  │  曲名  _________  │
│          │  │                │  │  艺人  _________  │
│          │  └────────────────┘  │  专辑  _________  │
│          │                      │  专辑艺人 _______  │
│          │ [全选] [批量转换]     │  作曲  _________  │
│          │                      │  年份  _________  │
│          │                      │  流派  _________  │
│          │                      │                   │
│          │                      │  [保存标签]        │
├──────────┴──────────────────────┴───────────────────┤
│ ▶ ████████████░░░░ 45%   5/12 首  ♪ songA.m4a     │
└─────────────────────────────────────────────────────┘
```

### 4.3 组件说明

| 组件 | 文件 | 功能 |
|------|------|------|
| 主窗口 | `main.qml` | 三栏布局 + 标题栏 |
| 侧边栏 | `Sidebar.qml` | 毛玻璃效果，导航按钮组 |
| 文件列表 | `FileList.qml` | 支持拖入文件、多选、右键菜单、状态图标 |
| 元数据面板 | `MetadataPanel.qml` | 表单布局，封面拖入区，保存按钮 |
| 播放条 | `PlayerBar.qml` | 播放/暂停、进度条、音量、当前曲目标题 |
| 毛玻璃按钮 | `GlassButton.qml` | 通用按钮组件 |
| 状态图标 | `StatusIcon.qml` | 5 种状态动画切换 |
| 环形进度 | `ProgressRing.qml` | 转换进度环 |

### 4.4 文件状态指示

| 状态 | 图标 | 说明 |
|------|------|------|
| 待处理 | ○ 灰色空心圆 | 刚导入，未操作 |
| 处理中 | ◌ 蓝色旋转环 | 正在转换 |
| 已完成 | ✅ 绿色勾 | 处理成功 |
| 失败 | ⚠️ 红色叹号 | 出错，悬停显示原因 |
| 已标签 | 🏷️ 紫色标签 | 元数据已保存 |

---

## 五、技术架构

### 5.1 技术栈

| 层 | 选型 | 版本 | 用途 |
|------|------|------|------|
| GUI | PySide6 | ≥6.5 | Qt Python 绑定，LGPL |
| UI 语言 | QML | Qt 6.x | 声明式界面 |
| 音频转换 | FFmpeg | 系统安装或捆绑 | 格式转换、分析 |
| Python FFmpeg 封装 | ffmpeg-python | latest | FFmpeg 命令构建 |
| 元数据 | mutagen | ≥1.47 | ID3/Vorbis/iTunes 标签读写 |
| 音频播放 | QtMultimedia | Qt 6.x 内置 | 音频解码播放 |
| 异步 | QThread / QRunnable | Qt 6.x 内置 | 批量任务不阻塞 UI |
| 打包 | PyInstaller | ≥6.0 | 打包 .exe / .app |
| Python | CPython | ≥3.10 | |

### 5.2 项目结构

```
apple-music-tool/
├── app/
│   ├── main.py                # 入口：创建 QApplication，加载 QML 引擎
│   ├── engine/
│   │   ├── __init__.py
│   │   ├── converter.py       # 转换引擎
│   │   ├── player.py          # 音频播放控制器
│   │   └── worker.py          # 异步任务队列（QThread）
│   ├── metadata/
│   │   ├── __init__.py
│   │   ├── reader.py          # 标签读取
│   │   └── writer.py          # 标签写入
│   ├── models/
│   │   ├── __init__.py
│   │   ├── audiofile.py       # AudioFile 数据类
│   │   └── task.py            # Task 数据类
│   └── utils/
│       ├── __init__.py
│       ├── ffmpeg_utils.py    # FFmpeg 命令构建辅助函数
│       └── format_detect.py   # 格式检测 + 合规检查
├── qml/
│   ├── main.qml               # 主窗口
│   ├── Sidebar.qml            # 侧边栏
│   ├── FileList.qml           # 文件列表
│   ├── MetadataPanel.qml      # 元数据编辑面板
│   ├── PlayerBar.qml          # 底部播放条
│   └── components/
│       ├── GlassButton.qml    # 毛玻璃按钮
│       ├── StatusIcon.qml     # 状态图标
│       └── ProgressRing.qml   # 环形进度
├── requirements.txt
└── README.md
```

### 5.3 核心模块设计

#### AudioFile 数据类

```python
@dataclass
class AudioFile:
    path: str                 # 源文件路径
    real_format: str          # 实际格式（flac/wav/mp3/alac/...）
    sample_rate: int          # 采样率 Hz
    bit_depth: int            # 位深度
    bitrate: int              # 比特率 bps
    duration: float           # 时长 秒
    channels: int             # 声道数
    file_size: int            # 文件大小 bytes
    status: AudioStatus       # 状态枚举
    error_message: str | None # 失败原因
    output_path: str | None   # 输出文件路径
```

#### 转换引擎 converter.py

```python
class ConversionEngine:
    def detect_format(self, path: str) -> AudioFile: ...
    def check_compliance(self, file: AudioFile) -> list[str]: ...
    # 返回不合规项列表，如 ["24-bit", "FLAC format"]
    
    def recommend_target(self, file: AudioFile) -> TargetFormat: ...
    # 返回推荐的目标格式和需要的转换操作
    
    def convert(self, file: AudioFile, target: TargetFormat,
                on_progress: Callable) -> AudioFile: ...
    # 执行转换，通过回调报告进度
    # → ffmpeg 子进程调用
```

#### 任务队列 worker.py

```python
class TaskWorker(QThread):
    task_queue: Queue[Task]
    
    def add_task(self, task: Task): ...
    def cancel_all(self): ...
    def pause_resume(self): ...
    
    # 信号：
    # task_started(task_id)
    # task_progress(task_id, percent)
    # task_finished(task_id, result)
    # task_failed(task_id, error_message)
```

#### 元数据 reader/writer

```python
# reader.py
def read_tags(path: str) -> dict[str, Any]:
    """读取 ID3/Vorbis/iTunes 标签，返回统一字典"""
    # 返回: {"title": str, "artist": str, "album": str, 
    #         "cover": bytes|None, ...}

# writer.py  
def write_tags(path: str, tags: dict[str, Any]): ...
def embed_cover(path: str, image_path: str): ...
```

### 5.4 数据流

```
用户拖入文件
    │
    ▼
FileList (QML) → Python: add_files(paths)
    │
    ▼
format_detect.py 分析每个文件 → 创建 AudioFile 列表
    │
    ▼
展示在 FileList（状态：○ 待处理）
    │
    ▼
用户点击「批量转换」
    │
    ▼
Worker 队列:
  每首 → converter.convert()
       → FFmpeg 子进程
       → 清除元数据标记
       → 输出 .m4a
       → 更新 AudioFile.status = 完成/失败
       → 信号通知 QML 刷新列表
```

---

## 六、错误处理

| 场景 | 处理方式 |
|------|----------|
| FFmpeg 未安装 | 启动时检测，引导安装或自动下载 |
| 不支持格式（WMA/OGG 等） | 标记为失败，提示"不支持的格式：xxx" |
| 文件过大（>200MB） | 标记为失败，提示"超过 Apple Music 200MB 限制" |
| 时长超限（>2h） | 标记为失败，提示"超过 Apple Music 2 小时限制" |
| 比特率过低（<96kbps） | 标记为失败，提示"比特率过低" |
| DRM 保护文件 | 标记为失败，提示"DRM 保护，无法处理" |
| 转换中断（进程崩溃） | 捕获异常，标记失败，记录错误日志 |
| 磁盘空间不足 | 写入前检查，提前报错 |

---

## 七、打包与分发

### 7.1 Windows

```bash
pyinstaller --onefile --windowed \
  --add-data "qml:qml" \
  --add-binary "ffmpeg.exe;." \
  --name "Fast Apple Music" \
  app/main.py
```

- 输出：单个 `Fast Apple Music.exe`
- FFmpeg 捆绑在包内（约 80MB FFmpeg + 50MB Python ≈ 130MB 安装包）
- 安装程序选项：NSIS 安装向导

### 7.2 macOS

```bash
pyinstaller --onefile --windowed \
  --add-data "qml:qml" \
  --name "Fast Apple Music" \
  app/main.py
```

- 输出：`Fast Apple Music.app`
- macOS 自带 FFmpeg 较弱，建议捆绑或要求 brew install ffmpeg
- DMG 分发

---

## 八、自审清单

| 检查项 | 状态 |
|--------|------|
| 无 TBD/TODO 占位符 | ✅ |
| UI 布局、交互流程、技术架构一致 | ✅ |
| v1 范围明确，不包含 A1/A2/A3/A6 | ✅ |
| 所有核心术语有明确定义 | ✅ |
| 错误场景有明确处理方案 | ✅ |
| 打包方案跨平台可行 | ✅ |
