---
name: security-audit
description: Use when asked to perform a security audit, scan for vulnerabilities, check for hardcoded secrets or credentials, detect injection risks, review config files for plaintext sensitive data, or assess overall code security hygiene. Triggers on "安全检查", "安全审计", "security audit", "安全漏洞", "密码泄露", "注入风险", "sensitive data", "vulnerability scan", "security scan".
---

# Security Audit — 代码安全审查

对代码做四维安全扫描：**密钥泄露 → 注入漏洞 → 配置安全 → 综合风险**。

## 审查维度

### 一、敏感信息泄露

扫描代码、配置、脚本中是否包含明文敏感数据：

| 检查项 | 搜索模式 |
|--------|---------|
| 密码/Token/Key | `password`, `passwd`, `secret`, `token`, `api_key`, `access_key`, `private_key` |
| 数据库连接串 | `mysql://`, `postgresql://`, `mongodb://` 中含密码 |
| 内网地址 | `192.168.*`, `10.*`, `172.16-31.*` |
| 邮箱/手机号 | `邮箱正则`, `手机号正则 1[3-9]\d{9}` |
| 硬编码用户路径 | `C:\Users\用户名` 或 `/home/用户名` |
| 云服务凭证 | `AKIA[0-9A-Z]{16}` (AWS), `eyJ` 开头 (JWT token) |
| 私钥 | `-----BEGIN RSA PRIVATE KEY-----` |

**严重级别：**
- 🔴 **严重**：明文凭据，可直接用于攻击
- 🟡 **注意**：暴露系统内部结构（用户名、内网地址）

### 二、注入漏洞

检查用户输入能否注入到执行环境：

| 注入类型 | 检查模式 | 本项目重点 |
|----------|---------|-----------|
| **命令注入** | `subprocess.run()`, `os.system()`, `os.popen()` | ✅ `ffmpeg_utils.py` + `format_detect.py` |
| **Shell 注入** | `shell=True` 参数 | ✅ 检查所有 subprocess 调用 |
| **路径遍历** | `os.path.join(user_input)`, `open(user_path)` | ✅ 用户可传入任意文件路径 |
| **参数注入** | 文件名以 `-` 开头被命令误解析为 flag | ✅ ffmpeg/ffprobe 命令行拼接 |
| **格式化字符串** | f-string/`%`/`.format()` 拼接命令参数 | ✅ 路径拼入命令 |
| **代码注入** | `eval()`, `exec()`, `__import__()`, `compile()` | ✅ 通用检查 |
| **QML 注入** | 用户元数据直接渲染到 QML | ⚠️ lyrics/tags 渲染到 UI |

**严重级别：**
- 🔴 **严重**：`shell=True` + 用户输入、`eval(user_input)`、路径可逃逸出工作目录
- 🟡 **注意**：列表参数但路径未验证、文件名以 `-` 打头可能被当作 flag

### 三、配置与文件安全

| 检查项 | 说明 |
|--------|------|
| **配置文件明文敏感信息** | `.json`/`.yaml`/`.toml`/`.ini`/`.env` 中是否有密钥 |
| **`.gitignore` 完整性** | 是否排除了 `__pycache__`, `*.pyc`, `venv/`, `.env`, `dist/`, `build/` |
| **启动脚本硬编码** | `.bat`/`.sh`/`.ps1` 中是否硬编码了路径或凭证 |
| **日志泄露** | `print()` / `logging` 是否输出密码、token、完整路径 |
| **临时文件** | 是否使用可预测的临时文件名 |

### 四、综合安全风险

| 检查项 | 说明 |
|--------|------|
| **依赖安全** | `requirements.txt` 中库是否存在已知 CVE（用 `pip-audit`） |
| **异常信息泄露** | `str(e)` 或 `traceback` 是否暴露内部路径和调用栈 |
| **反序列化风险** | `pickle.load()`, `yaml.load()` (非 `safe_load`) |
| **调试代码残留** | `pdb.set_trace()`, `breakpoint()`, `console.log` 含敏感信息 |
| **文件权限** | 创建文件时是否设置安全权限 |

---

## 标准审查流程

### Step 1：全量扫描
用 grep 对代码库做关键词扫描，列出所有命中。

### Step 2：逐条确认
对每个命中，读取上下文判断是真阳性还是误报。

### Step 3：定级
每个发现标严重级别：🔴严重 / 🟡注意 / 🟢低风险 / ℹ️信息

### Step 4：输出报告
按以下模板输出结构化报告。

---

## 审查报告模板

```
=== 安全检查报告 ===
项目: Fast Apple Music
审查时间: YYYY-MM-DD
审查范围: app/ + 配置文件 + 启动脚本

## 总体风险评级: 🔴高 / 🟡中 / 🟢低

## 发现汇总
🔴 严重:  N
🟡 注意:  N
🟢 低风险: N
ℹ️  信息:  N
━━━━━━━━━━━━━━━
合计:     N

## 详细发现

### 🔴 严重（需立即修复）
（逐一列出：文件:行号 / 问题描述 / 攻击场景 / 修复方案）

### 🟡 注意（建议修复）
（逐一列出）

### 🟢 低风险 & ℹ️ 信息
（逐一列出）

## 正面清单（已做对的）
- ✅ 无 shell=True
- ✅ 无 eval/exec
- ✅ subprocess 使用列表参数防 shell 注入

## 下一步行动
- [ ] 修复所有 🔴 项
- [ ] 评估 🟡 项修复优先级
- [ ] CI 中加入 pip-audit
- [ ] 确保 .gitignore 排除 .env 等敏感文件
```

---

## 本项目实战发现

审查时已发现以下可直接引用的案例：

### 🔴 发现 #1：启动脚本硬编码用户路径

**文件:** `启动.bat`
```batch
# ❌ 暴露了系统用户名和 Python 安装位置
"C:\Users\15269\AppData\Local\Python\bin\pythonw.exe"
```
**级别:** 🟡 注意
**修复:** `start "" pythonw.exe "%~dp0app/main.py"`

### 🔴 发现 #2：文件路径直传 ffmpeg 命令

**文件:** `app/utils/ffmpeg_utils.py:27`, `app/utils/format_detect.py:22`
```python
# ❌ 文件名 "-hidden.mp3" 可能被 ffmpeg 解析为命令行 flag
cmd = ["ffmpeg", "-y", "-i", input_path]
```
**级别:** 🟡 注意
**修复:** 使用 `--` 分隔符：`["ffmpeg", "-y", "-i", "--", input_path, output_path]`

### 🔴 发现 #3：异常信息泄露内部路径

**文件:** `app/utils/format_detect.py:27,35`
```python
# ❌ stderr 和 exception message 可能包含文件系统绝对路径
af.error_message = f"ffprobe 无法解析: {stderr_text}"
```
**级别:** 🟡 注意
**修复:** 对错误信息做路径脱敏，替换绝对路径为 `[PATH]`

### ✅ 正面清单

- ✅ 所有 subprocess.run() 都用列表参数（非 shell=True）
- ✅ 没有 eval()、exec() 调用
- ✅ 没有数据库（无 SQL 注入面）
- ✅ 没有硬编码密码或 API Key

---

## 快速扫描命令速查

审查时执行以下命令（按需，非必须全部运行）：

```bash
# 1. 扫描密钥泄露
grep -rInE "(password|secret|token|api[_-]?key|passwd)\s*=" app/ *.json *.bat 2>/dev/null

# 2. 扫描注入面
grep -rInE "subprocess\.|os\.system|eval\(|exec\(|shell\s*=\s*True" app/ 2>/dev/null

# 3. 扫描硬编码路径（Windows）
grep -rInE "[A-Z]:\\(Users|home)\\\\" *.bat *.sh *.json *.py 2>/dev/null

# 4. 扫描调试残留
grep -rInE "pdb\.|breakpoint\(\)|console\.log|# TODO.*password" app/ 2>/dev/null

# 5. 依赖漏洞扫描
pip-audit 2>/dev/null || echo "需安装 pip-audit: pip install pip-audit"

# 6. 检查 .gitignore 完整性
cat .gitignore 2>/dev/null || echo "⚠️ .gitignore 不存在！"
```

## 严重级别定义

| 级别 | 含义 | 典型场景 |
|------|------|---------|
| 🔴 **严重** | 可直接导致数据泄露或系统被控 | 明文密码、`shell=True`+用户输入、可写 `eval()` |
| 🟡 **注意** | 增加攻击面，但需一定条件利用 | 硬编码路径、参数注入风险、错误信息泄露内部结构 |
| 🟢 **低风险** | 理论弱点，实际利用难度高 | 调试信息残留、文件权限宽松 |
| ℹ️ **信息** | 最佳实践建议，非漏洞 | 无速率限制、建议添加安全头 |
