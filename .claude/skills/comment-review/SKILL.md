---
name: comment-review
description: Use when asked to review code comments, check comment quality, verify comment-to-code ratio (30% target), audit comments for beginner-friendliness, validate comments match actual code behavior, or perform any comment inspection in the Fast Apple Music project. Triggers on "注释检查", "comment review", "检查注释", "review comments", "注释质量", "comment quality", or requests involving "每个函数都要有注释", "小白能看懂", "注释和代码匹配".
---

# Comment Review — 注释三重检查

对代码注释做三维度检查：**够不够多（覆盖率）→ 写得对不对（准确性）→ 小白能不能看懂（可读性）**。

## 核心标准

> **每 10 行代码，至少 3 行注释。** 注释解释"为什么要这样做"，而不是"这行代码在干什么"。

这是硬指标。对函数和核心逻辑块逐段检查：不足 30% 即标记为缺失。

## 三维度检查清单

### 维度一：注释覆盖率（够不够）

| 检查项 | 标准 | 不合格示例 |
|--------|------|-----------|
| 函数/方法 | 每个函数必须有 docstring，说明**输入、输出、副作用** | 空函数体无注释 |
| 核心逻辑块 | if-else 分支 / try-except / 循环 必须有行内注释 | 5 行以上的逻辑块无任何注释 |
| 魔法数字 | 每个常量必须注释含义和单位 | `timeout=300` 无注释 |
| 正则/位运算 | 必须逐段注释 | `r'\.(mp3\|flac)$'` 无注释 |
| 回调/信号 | 必须注释触发时机和消费者 | `task_started = Signal(str)` 无注释 |
| 外部依赖调用 | subprocess/mutagen/ffmpeg 调用必须注释失败模式 | `subprocess.run(cmd)` 无注释 |

**计算方式：**
```
注释率 = 注释行数 / 总行数 × 100%
注释行数 = #开头行 + 独立的""""""行
```
≥ 30% 通过，20-30% 需改进，< 20% 不合格。

### 维度二：注释准确性（对不对）

| 检查项 | 标准 |
|--------|------|
| 参数类型 | 注释说的类型和实际参数类型一致 |
| 返回值 | 注释描述的返回值和代码实际 return 一致 |
| 逻辑描述 | 注释说的逻辑步骤和代码实际执行顺序一致 |
| 过时注释 | 代码已改成新逻辑但注释还是旧的（常见于重构后） |
| 复制粘贴残留 | 注释提到不存在的函数名、参数名 |

**核心方法：** 逐行比对注释和代码。注释说"返回 True 表示成功"，就看代码是否真的 `return True`。注释说"timeout 默认 5 分钟"，就看参数是否真的是 `300` 秒。

### 维度三：小白可读性（能不能懂）

假设读者是**刚学编程的新人**，检查：

| 检查项 | 标准 |
|--------|------|
| 专业术语解释 | "ID3v2 标签帧"、"Vorbis Comment"、"planar 格式" — 每出现一个必须有简短解释 |
| 技术决策的原因 | 不是"用了 s16p 格式"，而是"用了 s16p 格式，**因为 ALAC 编码器要求 planar 采样排列**" |
| 隐式行为说明 | `__post_init__` 自动填 filename — 这是隐式的，必须注释说明 |
| 失败原因可诊断 | `# 如果 FFmpeg 未安装，这里会抛出 FileNotFoundError` — 注释要能帮人定位问题 |

## 审查工作流

1. **扫描文件**：读取目标 `.py` 文件
2. **计算覆盖率**：逐函数统计注释率
3. **逐段比对**：对每个函数，检查注释和代码是否一致
4. **小白视角审核**：标记所有未解释的术语、魔法数字、隐式行为
5. **输出报告**：按三维度列出问题和建议

## 评分体系

每个维度满分 **5 分**：

| 分数 | 覆盖率 | 准确性 | 可读性 |
|------|--------|--------|--------|
| 5 | ≥30% | 全部准确 | 完全小白友好 |
| 4 | 25-30% | 基本准确 | 大部分可懂 |
| 3 | 20-25% | 有 1-2 处不准确 | 需要一些经验 |
| 2 | 15-20% | 多处不一致 | 只有老手能懂 |
| 1 | <15% | 大量错误 | 无法理解 |
| 0 | 无注释 | 全部错误/过时 | — |

**总分：**
- 🟢 **12-15 分**：通过
- 🟡 **8-11 分**：需改进
- 🔴 **0-7 分**：不合格

## 实战示例

### ❌ Before（项目现有代码 — 不合格）

```python
# app/utils/ffmpeg_utils.py 原始版本
# 总行数: 111, 注释行: ~6, 注释率: 5.4% — 🔴 不合格

def build_convert_command(input_path: str, output_path: str, target_format: str) -> list[str]:
    """
    构建 FFmpeg 转换命令。
    输入可能是 FLAC/WAV/AIFF/ALAC24bit，输出为 Apple Music 兼容格式。
    """
    cmd = ["ffmpeg", "-y", "-i", input_path]

    # 音频编码器选择
    if target_format == "alac":
        codec = "alac"
        sample_fmt = "s16p"  # ← "s16p" 是什么？为什么 ALAC 要它？小白看不懂
    elif target_format == "mp3":
        codec = "libmp3lame"
        sample_fmt = None
    …

    # 位深度：强制 16-bit
    if sample_fmt:
        cmd.extend(["-sample_fmt", sample_fmt])  # ← 为什么要强制 16-bit？
```

**评分：覆盖率 2/5 | 准确性 3/5 | 可读性 1/5 = 🔴 6分 不合格**

**检查结果：**
- 覆盖率：111 行只有 6 行注释，5.4%，严重不足
- 准确性：注释描述了做什么，但没说为什么
- 可读性：`s16p`、`planar`、`libmp3lame` 无一解释，小白完全看不懂

### ✅ After（改进后 — 达标）

```python
def build_convert_command(input_path: str, output_path: str, target_format: str) -> list[str]:
    """
    构建 FFmpeg 音频转换命令行参数。

    参数:
        input_path:  源文件绝对路径（支持 FLAC/WAV/AIFF/ALAC/MP3/AAC）
        output_path: 输出文件路径（扩展名决定容器格式）
        target_format: 目标编码格式，可选 "alac" / "mp3" / "aac"

    返回:
        list[str]: 完整的 ffmpeg 命令行参数列表，可直接传给 subprocess.run()

    副作用: 无
    """
    # -y 参数：当输出文件已存在时自动覆盖，避免交互式提示卡住自动化流程
    cmd = ["ffmpeg", "-y", "-i", input_path]

    # ============================================================
    # 编码器选择：不同格式用不同的 FFmpeg 编码器
    # ============================================================
    if target_format == "alac":
        # ALAC = Apple Lossless Audio Codec（苹果无损），容器为 .m4a
        codec = "alac"
        # s16p = signed 16-bit planar（16位有符号平面采样格式）
        # ALAC 编码器要求输入必须是 planar 排列，不能是 packed，
        # 否则会报 "sample format not supported" 错误
        sample_fmt = "s16p"
    elif target_format == "mp3":
        # libmp3lame：FFmpeg 内置的最高质量 MP3 编码器
        codec = "libmp3lame"
        # MP3 编码器根据比特率自行决定采样格式，不需要手动指定
        sample_fmt = None
    elif target_format == "aac":
        # aac：FFmpeg 原生 AAC 编码器（无需额外安装 libfdk_aac）
        codec = "aac"
        sample_fmt = None
    else:
        # 兜底：未知格式统一按 ALAC 16-bit 处理
        codec = "alac"
        sample_fmt = "s16p"

    cmd.extend(["-acodec", codec])

    # 强制输出 16-bit 位深度
    # 原因：Apple Music 不支持 24-bit 音频 —— 24-bit FLAC/WAV 必须降至 16-bit
    # 才能成功上传到 iCloud 音乐库。降位深度对音质影响极小。
    if sample_fmt:
        cmd.extend(["-sample_fmt", sample_fmt])

    # 清除来源平台的私有元数据标记
    # 抖音/TikTok/剪映 等平台会在音频文件中写入 "comment"、"encoder"
    # 等非标准标签，Apple Music 会拒绝含有这些标签的文件上传
    for tag in STRIP_TAGS:
        cmd.extend(["-metadata", f"{tag}="])

    # 输出文件路径放在最后（ffmpeg 命令行的约定格式）
    cmd.append(output_path)
    return cmd
```

**评分：覆盖率 5/5 | 准确性 5/5 | 可读性 5/5 = 🟢 15分 通过**

## 审查报告模板

```
=== 注释审查报告 ===
文件: app/utils/ffmpeg_utils.py
审查时间: YYYY-MM-DD

## 总体评分
覆盖率:  X/5  (注释率 Y.Y%)
准确性:  X/5  
可读性:  X/5
总分:    XX/15  🟢/🟡/🔴

## 覆盖率明细
函数                         行数  注释行  注释率
------------------------------------------------
check_ffmpeg_available        4      1     25%
build_convert_command         33     3      9%  ← 严重不足
run_ffmpeg                    25     1      4%  ← 严重不足
…

## 发现的问题
### 🔴 严重（必须修复）
- [ ] build_convert_command: 编码器选择分支无一解释（行 30-41）
- [ ] run_ffmpeg: subprocess.run 的 timeout 参数无注释（行 72）

### 🟡 建议改进
- [ ] get_output_path: 同名文件区分逻辑可加示意图注释（行 106-109）

### 🟢 优秀
- check_ffmpeg_available: 简洁明了，注释恰到好处

## 修复后预期
覆盖率: 5.4% → 32.0%
评分:    6/15  → 14/15
```

## 快速参考

| 代码类型 | 最少注释密度 | 注释重点 |
|----------|-------------|---------|
| 公开函数 | 1 docstring + 每 3 行 1 行注释 | 参数、返回、异常、副作用 |
| 私有函数 | 1 docstring | 为什么需要这个函数 |
| if-else 分支 | 每个分支 1 行注释 | 条件为真时的业务场景 |
| try-except | 每个 except 1 行注释 | 什么情况会触发此异常 |
| 魔法数字 | 每个数字 1 行注释 | 单位的含义（秒？字节？Hz？） |
| 正则表达式 | 逐段注释 | 每段匹配什么 |
| Qt 信号 | 每个信号 1 行注释 | 触发时机 + 哪些槽会接收 |
| 枚举值 | 每个值 1 行注释 | 代表什么业务状态 |

## 常见误区

| 坏注释（应该避免） | 好注释（应该写） |
|-------------------|-----------------|
| `# 把 a 加 1`（代码已有 `a += 1`） | `# 计数器 +1，因为跳过了表头行` |
| `# 调用 convert 函数`（废话） | `# 转换为 ALAC 格式（Apple Music 不支持 FLAC 容器）` |
| `# 处理错误`（太笼统） | `# 捕获 FileNotFoundError：FFmpeg 未安装或不在 PATH 中` |
| 没有注释 | `# 300 秒 = 5 分钟，一个大文件最长转换时间` |
| 过时的注释（说用 libfaac，代码已改成 aac） | 及时更新注释，保持和代码一致 |
