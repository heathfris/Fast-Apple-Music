"""音频标签写入 — 基于 mutagen"""
import os
import tempfile
import shutil
from mutagen import File as MutagenFile
from mutagen.flac import FLAC, Picture
from mutagen.mp3 import MP3
from mutagen.mp4 import MP4, MP4Cover
from mutagen.id3 import (
    ID3, TIT2, TPE1, TALB, TPE2, TCOM,
    TDRC, TCON, APIC, USLT, delete
)


def _get_image_mime(data: bytes) -> str:
    """通过文件头魔术字节检测图片格式"""
    if data[:8] == b'\x89PNG\r\n\x1a\n':
        return "image/png"
    if data[:2] == b'\xff\xd8':
        return "image/jpeg"
    if data[:4] == b'GIF8':
        return "image/gif"
    if data[:4] == b'RIFF' and data[8:12] == b'WEBP':
        return "image/webp"
    return "image/jpeg"  # fallback


def _get_mp4_cover_format(data: bytes) -> int:
    """根据图片数据确定 MP4Cover 格式常量"""
    if data[:8] == b'\x89PNG\r\n\x1a\n':
        return MP4Cover.FORMAT_PNG
    return MP4Cover.FORMAT_JPEG


def write_tags(path: str, tags: dict):
    """将标签写入音频文件。对 MP3 使用健壮写入策略避免 'cant sync to MPEG frame'。"""
    if not os.path.exists(path):
        raise FileNotFoundError(f"文件不存在: {path}")

    audio = MutagenFile(path)
    if audio is None:
        raise ValueError(f"不支持的文件格式: {path}")

    if isinstance(audio, MP3):
        _write_mp3_robust(path, audio, tags)
    elif isinstance(audio, FLAC):
        _write_flac_tags(audio, tags)
        audio.save()
    elif isinstance(audio, MP4):
        _write_mp4_tags(audio, tags)
        audio.save()


def _write_mp3_robust(path: str, audio: MP3, tags: dict):
    """
    健壮的 MP3 标签写入。
    策略：先删旧标签 → 建新标签 → 尝试正常保存。
    如果失败（MPEG sync error），则删除标签后用 ID3 直接操作文件。
    """
    # 策略 1：删除旧标签，建新标签，正常保存
    try:
        audio.delete()
        audio.tags = ID3()
        _write_mp3_tags(audio, tags)
        audio.save(v2_version=3)
        return
    except Exception:
        pass

    # 策略 2：用 ID3 直接操作（绕过 mutagen 的 MP3 wrapper 的 MPEG 同步问题）
    try:
        # 先删除已有的 ID3 标签（包括 v1 和 v2）
        delete(path, delete_v1=True, delete_v2=True)
        # 创建全新的 ID3v2.3 标签
        id3 = ID3()
        _set_id3(id3, TIT2, "title", tags)
        _set_id3(id3, TPE1, "artist", tags)
        _set_id3(id3, TALB, "album", tags)
        _set_id3(id3, TPE2, "album_artist", tags)
        _set_id3(id3, TCOM, "composer", tags)
        _set_id3(id3, TCON, "genre", tags)

        year = tags.get("year", "")
        if year:
            id3.add(TDRC(encoding=3, text=str(year)))

        cover = tags.get("cover_data")
        if cover:
            id3.add(APIC(
                encoding=3, mime=_get_image_mime(cover), type=3,
                desc="Cover", data=cover
            ))

        # 保存 ID3 标签，用 v2_version=3 确保兼容 Apple Music
        id3.save(path, v2_version=3)
        return
    except Exception:
        pass

    # 策略 3：终极兜底 — 用 FFmpeg 重写标签
    _write_via_ffmpeg(path, tags)


def _write_via_ffmpeg(path: str, tags: dict):
    """
    用 FFmpeg 重写标签 — 最兼容的方式。
    但会重新编码音频，仅作为最后兜底。
    """
    import subprocess
    import tempfile

    # 构建元数据参数
    meta_args = []
    mapping = {
        "title": "title", "artist": "artist", "album": "album",
        "album_artist": "album_artist", "composer": "composer",
        "year": "date", "genre": "genre",
    }
    for dict_key, ff_key in mapping.items():
        val = tags.get(dict_key, "")
        if val:
            meta_args.extend(["-metadata", f"{ff_key}={val}"])

    if not meta_args:
        return  # 没有要写入的标签

    # 写到临时文件然后替换
    tmp_path = path + ".tmp.mp3"
    cmd = ["ffmpeg", "-y", "-i", path, "-acodec", "copy"] + meta_args + [tmp_path]
    result = subprocess.run(cmd, capture_output=True, timeout=120)
    if result.returncode == 0 and os.path.exists(tmp_path):
        shutil.move(tmp_path, path)
    else:
        raise RuntimeError(f"FFmpeg 写入失败: {result.stderr.decode('utf-8', errors='replace')[:200]}")


def _write_mp3_tags(audio: MP3, tags: dict):
    """写入 MP3 ID3v2 标签"""
    if audio.tags is None:
        audio.tags = ID3()

    _set_id3(audio.tags, TIT2, "title", tags)
    _set_id3(audio.tags, TPE1, "artist", tags)
    _set_id3(audio.tags, TALB, "album", tags)
    _set_id3(audio.tags, TPE2, "album_artist", tags)
    _set_id3(audio.tags, TCOM, "composer", tags)
    _set_id3(audio.tags, TCON, "genre", tags)

    year = tags.get("year", "")
    if year:
        audio.tags.add(TDRC(encoding=3, text=str(year)))

    # 封面
    cover = tags.get("cover_data")
    if cover:
        # 清除旧封面
        for k in list(audio.tags.keys()):
            if k.startswith("APIC"):
                del audio.tags[k]
        audio.tags.add(APIC(
            encoding=3, mime=_get_image_mime(cover), type=3,
            desc="Cover", data=cover
        ))


def _write_flac_tags(audio: FLAC, tags: dict):
    """写入 FLAC Vorbis Comment 标签"""
    _set_vorbis(audio, "title", "title", tags)
    _set_vorbis(audio, "artist", "artist", tags)
    _set_vorbis(audio, "album", "album", tags)
    _set_vorbis(audio, "albumartist", "album_artist", tags)
    _set_vorbis(audio, "composer", "composer", tags)
    _set_vorbis(audio, "date", "year", tags)
    _set_vorbis(audio, "genre", "genre", tags)

    # 封面
    cover = tags.get("cover_data")
    if cover:
        audio.clear_pictures()
        pic = Picture()
        pic.type = 3
        pic.mime = _get_image_mime(cover)
        pic.desc = "Cover"
        pic.data = cover
        audio.add_picture(pic)


def _write_mp4_tags(audio: MP4, tags: dict):
    """写入 M4A/MP4 标签"""
    _set_mp4(audio, "\xa9nam", "title", tags)
    _set_mp4(audio, "\xa9ART", "artist", tags)
    _set_mp4(audio, "\xa9alb", "album", tags)
    _set_mp4(audio, "aART", "album_artist", tags)
    _set_mp4(audio, "\xa9wrt", "composer", tags)
    _set_mp4(audio, "\xa9day", "year", tags)
    _set_mp4(audio, "\xa9gen", "genre", tags)

    # 封面
    cover = tags.get("cover_data")
    if cover:
        mp4_cover = MP4Cover(cover, imageformat=_get_mp4_cover_format(cover))
        audio["\xa9cov"] = [mp4_cover]


def _set_id3(id3, frame_cls, key: str, tags: dict):
    val = tags.get(key, "")
    if val:
        id3.add(frame_cls(encoding=3, text=str(val)))


def _set_vorbis(audio, tag_key: str, dict_key: str, tags: dict):
    val = tags.get(dict_key, "")
    if val:
        audio[tag_key] = str(val)


def _set_mp4(audio, tag_key: str, dict_key: str, tags: dict):
    val = tags.get(dict_key, "")
    if val:
        audio[tag_key] = [str(val)]


def write_lyrics(path: str, lyrics: str):
    """将歌词写入音频文件 — 一次打开，读写合并"""
    if not os.path.exists(path):
        raise FileNotFoundError(f"文件不存在: {path}")

    audio = MutagenFile(path)
    if audio is None:
        raise ValueError(f"不支持的文件格式: {path}")

    if isinstance(audio, MP3):
        if audio.tags is None:
            audio.tags = ID3()
        # 清除旧 USLT 帧
        for k in list(audio.tags.keys()):
            if k.startswith("USLT"):
                del audio.tags[k]
        audio.tags.add(USLT(encoding=3, lang="eng", desc="", text=lyrics))
    elif isinstance(audio, FLAC):
        audio["lyrics"] = lyrics
    elif isinstance(audio, MP4):
        audio["\xa9lyr"] = [lyrics]

    audio.save()
