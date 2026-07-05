"""音频标签读取 — 基于 mutagen"""
import os
from mutagen import File as MutagenFile
from mutagen.flac import FLAC
from mutagen.mp3 import MP3
from mutagen.mp4 import MP4
from mutagen.id3 import ID3, APIC


def read_tags(path: str) -> dict:
    """
    读取音频文件的元数据标签，返回统一格式的字典。
    支持的标签：title, artist, album, album_artist,
               composer, year, genre, cover_data
    """
    if not os.path.exists(path):
        return _empty_tags()

    try:
        audio = MutagenFile(path)
    except Exception:
        return _empty_tags()

    if audio is None:
        return _empty_tags()

    tags = _empty_tags()

    # MP3 (ID3v2)
    if isinstance(audio, MP3):
        id3 = audio.tags
        if id3:
            tags["title"] = _get_text(id3, "TIT2")
            tags["artist"] = _get_text(id3, "TPE1")
            tags["album"] = _get_text(id3, "TALB")
            tags["album_artist"] = _get_text(id3, "TPE2")
            tags["composer"] = _get_text(id3, "TCOM")
            tags["year"] = _get_text(id3, "TDRC") or _get_text(id3, "TYER")
            tags["genre"] = _get_text(id3, "TCON")
            # 歌词 (USLT)
            for key in id3:
                if key.startswith("USLT"):
                    tags["lyrics"] = str(id3[key].text)
                    break
            # 专辑封面
            for key in id3:
                if key.startswith("APIC"):
                    tags["cover_data"] = id3[key].data
                    break

    # FLAC
    elif isinstance(audio, FLAC):
        tags["title"] = _get_vorbis(audio, "title")
        tags["artist"] = _get_vorbis(audio, "artist")
        tags["album"] = _get_vorbis(audio, "album")
        tags["album_artist"] = _get_vorbis(audio, "albumartist")
        tags["composer"] = _get_vorbis(audio, "composer")
        tags["year"] = _get_vorbis(audio, "date")
        tags["genre"] = _get_vorbis(audio, "genre")
        # FLAC 歌词
        tags["lyrics"] = _get_vorbis(audio, "lyrics")
        # FLAC 封面
        if audio.pictures:
            tags["cover_data"] = audio.pictures[0].data

    # M4A / MP4 (ALAC / AAC)
    elif isinstance(audio, MP4):
        tags["title"] = _get_mp4(audio, "\xa9nam")
        tags["artist"] = _get_mp4(audio, "\xa9ART")
        tags["album"] = _get_mp4(audio, "\xa9alb")
        tags["album_artist"] = _get_mp4(audio, "aART")
        tags["composer"] = _get_mp4(audio, "\xa9wrt")
        tags["year"] = _get_mp4(audio, "\xa9day")
        tags["genre"] = _get_mp4(audio, "\xa9gen")
        # M4A 歌词 (©lyr)
        tags["lyrics"] = _get_mp4(audio, "\xa9lyr")
        # M4A 封面
        covr = audio.get("\xa9cov", [])
        if covr:
            tags["cover_data"] = bytes(covr[0])

    return tags


def _empty_tags() -> dict:
    return {
        "title": "", "artist": "", "album": "",
        "album_artist": "", "composer": "",
        "year": "", "genre": "", "cover_data": None,
        "lyrics": "",
    }


def _get_text(id3, frame_id: str) -> str:
    """从 ID3 标签中安全获取文本帧"""
    frame = id3.get(frame_id)
    if frame and frame.text:
        return str(frame.text[0]) if frame.text else ""
    return ""


def _get_vorbis(audio, key: str) -> str:
    """从 Vorbis Comment 中安全获取文本"""
    values = audio.get(key, [])
    return str(values[0]) if values else ""


def _get_mp4(audio, key: str) -> str:
    """从 MP4 标签中安全获取文本"""
    values = audio.get(key, [])
    return str(values[0]) if values else ""
