# Fast Apple Music

一键将音频文件转换为 Apple Music 兼容格式。拖入 → 转换 → 导入 Apple Music。

## 功能
- 拖入音频文件，自动检测格式并转换为 Apple Music 兼容格式
- 清除来源平台残留标记（抖音等）
- 批量处理，异步不卡界面
- 内置试听播放器
- 元数据编辑（封面、艺人、专辑等）

## 安装

### 前置依赖
- Python 3.10+
- FFmpeg（需在系统 PATH 中）

### 安装
```bash
pip install -r requirements.txt
```

### 运行
```bash
python app/main.py
```

## 打包
```bash
pyinstaller --onefile --windowed --add-data "qml:qml" --name "Fast Apple Music" app/main.py
```
