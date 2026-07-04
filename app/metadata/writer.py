"""音频标签写入 — 基于 mutagen"""
import os
from mutagen import File as MutagenFile
from mutagen.flac import FLAC, Picture
from mutagen.mp3 import MP3
from mutagen.mp4 import MP4, MP4Cover
from mutagen.id3 import (
    ID3, TIT2, TPE1, TALB, TPE2, TCOM,
    TDRC, TCON, APIC
)


def write_tags(path: str, tags: dict):
    """
    将标签写入音频文件。
    tags 字典格式: {"title": "...", "artist": "...", ...}
    """
    if not os.path.exists(path):
        raise FileNotFoundError(f"文件不存在: {path}")

    audio = MutagenFile(path)
    if audio is None:
        raise ValueError(f"不支持的文件格式: {path}")

    if isinstance(audio, MP3):
        _write_mp3_tags(audio, tags)
    elif isinstance(audio, FLAC):
        _write_flac_tags(audio, tags)
    elif isinstance(audio, MP4):
        _write_mp4_tags(audio, tags)

    audio.save()


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
            encoding=3, mime="image/jpeg", type=3,
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
        pic.mime = "image/jpeg"
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
        mp4_cover = MP4Cover(cover, imageformat=MP4Cover.FORMAT_JPEG)
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
