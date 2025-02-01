#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sqlite3
import subprocess
import logging
import traceback
from datetime import datetime
from moviepy.editor import VideoFileClip
import pandas as pd
from PIL import Image, ImageFile

###############################################################################
# Logging konfigurieren
###############################################################################
logging.basicConfig(
    filename='media_processing.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

###############################################################################
# Pfade konfigurieren
###############################################################################
OLD_DB_PATH = os.path.join(os.getcwd(), "filtered_tiktok_media_metadata.db")
NEW_DB_DIR = os.path.join(os.getcwd(), "archiv")
os.makedirs(NEW_DB_DIR, exist_ok=True)
NEW_DB_PATH = os.path.join(NEW_DB_DIR, "filtered_tiktok_media.db")

EXTERNAL_STORAGE_BASE = "/mnt/HC_Volume_101955489/tricktok-archiv"

VIDEO_SUBFOLDER = "video"
AUDIO_SUBFOLDER = "audio"
SCREENSHOTS_SUBFOLDER = "screenshots"
SCREENSHOT_THUMBS_SUBFOLDER = "screenshot_thumbnails"
STORYBOARDS_SUBFOLDER = "storyboards"
STORYBOARD_THUMBS_SUBFOLDER = "storyboard_thumbnails"

TABLE_NAME = "media_info"

###############################################################################
# Tabelle definieren (36 Spalten inkl. "test_column")
###############################################################################
SCHEMA = f"""
DROP TABLE IF EXISTS {TABLE_NAME};  -- Alte Tabelle wegwerfen, Vorsicht!

CREATE TABLE {TABLE_NAME} (
    new_id INTEGER PRIMARY KEY AUTOINCREMENT,
    id TEXT,
    url TEXT UNIQUE,
    title TEXT,
    description TEXT,
    duration REAL,
    view_count INTEGER,
    like_count INTEGER,
    repost_count INTEGER,
    comment_count INTEGER,
    uploader TEXT,
    channel TEXT,
    channel_id TEXT,
    channel_url TEXT,
    track TEXT,
    album TEXT,
    artists TEXT,
    timestamp INTEGER,
    extractor TEXT,
    german_title TEXT,
    german_description TEXT,

    file_extension TEXT,
    creation_date TEXT,
    length_seconds INTEGER,

    video_path TEXT,
    video_size INTEGER,

    audio_path TEXT,
    audio_size INTEGER,

    screenshot_path TEXT,
    screenshot_size INTEGER,

    screenshot_thumbnail_path TEXT,
    screenshot_thumbnail_size INTEGER,

    storyboard_path TEXT,
    storyboard_size INTEGER,

    storyboard_thumbnail_path TEXT,
    storyboard_thumbnail_size INTEGER,

    test_column TEXT
);
"""

###############################################################################
# Hilfsfunktionen
###############################################################################
def safe_filename(title, max_length=200):
    safe_title = ''.join(c for c in title if c.isalnum() or c in (' ', '-', '_')).strip()
    if len(safe_title) > max_length:
        safe_title = safe_title[:max_length]
    return safe_title

def get_modification_date(file_path):
    stats = os.stat(file_path)
    return datetime.fromtimestamp(stats.st_mtime).strftime('%Y-%m-%d %H:%M:%S')

def get_file_size(file_path):
    if not os.path.exists(file_path):
        return 0
    return os.path.getsize(file_path)

def link_exists(cursor, link):
    cursor.execute(f"SELECT 1 FROM {TABLE_NAME} WHERE url = ?", (link,))
    return cursor.fetchone() is not None

def relative_path_in_storage(full_path):
    return os.path.relpath(full_path, EXTERNAL_STORAGE_BASE)

def create_screenshot(video_path, screenshot_full_path):
    try:
        os.makedirs(os.path.dirname(screenshot_full_path), exist_ok=True)
        subprocess.run([
            "ffmpeg", "-i", video_path, "-ss", "00:00:01.000", "-vframes", "1",
            screenshot_full_path, "-y"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        logging.info(f"Screenshot erstellt: {screenshot_full_path}")
    except Exception as e:
        logging.error(f"Fehler beim Erstellen des Screenshots: {e}")
        traceback.print_exc()

def create_screenshot_thumbnail(screenshot_path, thumbnail_path):
    from PIL import Image
    try:
        os.makedirs(os.path.dirname(thumbnail_path), exist_ok=True)
        with Image.open(screenshot_path) as img:
            new_size = (img.width // 2, img.height // 2)
            img_thumb = img.resize(new_size)
            img_thumb.save(thumbnail_path, "JPEG", quality=85)
        logging.info(f"Screenshot-Thumbnail erstellt: {thumbnail_path}")
    except Exception as e:
        logging.error(f"Fehler beim Erstellen des Screenshot-Thumbnails: {e}")
        traceback.print_exc()

def create_storyboard(video_path, storyboard_full_path):
    try:
        os.makedirs(os.path.dirname(storyboard_full_path), exist_ok=True)
        subprocess.run([
            "ffmpeg", "-i", video_path,
            "-vf", "fps=1,scale=320:-1,tile=5x5",
            "-frames:v", "1", storyboard_full_path, "-y"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        logging.info(f"Storyboard erstellt: {storyboard_full_path}")
    except Exception as e:
        logging.error(f"Fehler beim Erstellen des Storyboards: {e}")
        traceback.print_exc()

def create_storyboard_thumbnail(storyboard_path, storyboard_thumb_path):
    from PIL import Image, ImageFile
    ImageFile.LOAD_TRUNCATED_IMAGES = True
    try:
        os.makedirs(os.path.dirname(storyboard_thumb_path), exist_ok=True)
        with Image.open(storyboard_path) as sb:
            new_size = (sb.width // 2, sb.height // 2)
            sb_thumb = sb.resize(new_size)
            sb_thumb.save(storyboard_thumb_path, 'JPEG', quality=85)
        logging.info(f"Storyboard-Thumbnail erstellt: {storyboard_thumb_path}")
    except Exception as e:
        logging.error(f"Fehler beim Erstellen des Storyboard-Thumbnails: {e}")
        traceback.print_exc()

###############################################################################
# Hauptverarbeitung
###############################################################################
def download_and_process_media(row, cursor, connection):
    # Spalten aus alter DB
    url = row.url
    old_id = str(getattr(row, 'id', ""))
    title = getattr(row, 'title', "")
    description = getattr(row, 'description', "")
    duration = getattr(row, 'duration', 0) or 0
    view_count = getattr(row, 'view_count', 0) or 0
    like_count = getattr(row, 'like_count', 0) or 0
    repost_count = getattr(row, 'repost_count', 0) or 0
    comment_count = getattr(row, 'comment_count', 0) or 0
    uploader = getattr(row, 'uploader', "unknown_uploader")
    channel = getattr(row, 'channel', "")
    channel_id = getattr(row, 'channel_id', "")
    channel_url = getattr(row, 'channel_url', "")
    track = getattr(row, 'track', "")
    album = getattr(row, 'album', "")
    artists = getattr(row, 'artists', "")
    timestamp = getattr(row, 'timestamp', 0) or 0
    extractor = getattr(row, 'extractor', "")
    german_title = getattr(row, 'german_title', "")
    german_description = getattr(row, 'german_description', "")

    # Prüfen, ob URL schon vorhanden
    if link_exists(cursor, url):
        logging.info(f"Überspringe bereits vorhandene URL: {url}")
        return

    # Ordner pro Uploader
    safe_uploader = safe_filename(uploader, max_length=100)
    base_path = os.path.join(EXTERNAL_STORAGE_BASE, safe_uploader)
    os.makedirs(base_path, exist_ok=True)

    video_dir = os.path.join(base_path, VIDEO_SUBFOLDER)
    audio_dir = os.path.join(base_path, AUDIO_SUBFOLDER)
    screenshots_dir = os.path.join(base_path, SCREENSHOTS_SUBFOLDER)
    screenshot_thumbs_dir = os.path.join(base_path, SCREENSHOT_THUMBS_SUBFOLDER)
    storyboards_dir = os.path.join(base_path, STORYBOARDS_SUBFOLDER)
    storyboard_thumbs_dir = os.path.join(base_path, STORYBOARD_THUMBS_SUBFOLDER)

    for d in [
        video_dir, audio_dir,
        screenshots_dir, screenshot_thumbs_dir,
        storyboards_dir, storyboard_thumbs_dir
    ]:
        os.makedirs(d, exist_ok=True)

    # Video-Titel via yt-dlp
    try:
        result = subprocess.run(
            ["yt-dlp", "--get-filename", "-o", "%(title)s", url],
            capture_output=True, text=True, check=True
        )
        dynamic_title = result.stdout.strip()
        if dynamic_title:
            title = dynamic_title
    except subprocess.CalledProcessError:
        pass

    safe_title = safe_filename(title, max_length=150)
    file_extension = "mp4"

    # Pfade
    video_full_path = os.path.join(video_dir, f"{safe_title}.{file_extension}")
    audio_full_path = os.path.join(audio_dir, f"{safe_title}.mp3")
    screenshot_path_full = os.path.join(screenshots_dir, f"{safe_title}_screenshot.jpg")
    screenshot_thumb_path_full = os.path.join(screenshot_thumbs_dir, f"{safe_title}_screenshot_thumb.jpg")
    storyboard_path_full = os.path.join(storyboards_dir, f"{safe_title}_storyboard.jpg")
    storyboard_thumb_path_full = os.path.join(storyboard_thumbs_dir, f"{safe_title}_storyboard_thumb.jpg")

    # Download Video
    try:
        logging.info(f"Download gestartet für: {url}")
        subprocess.run(["yt-dlp", "-o", video_full_path, url],
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        logging.info(f"Download abgeschlossen: {video_full_path}")
    except subprocess.CalledProcessError as e:
        logging.error(f"Fehler beim Herunterladen: {url} - {e}")
        return

    # Audio extrahieren
    try:
        logging.info(f"Erstelle MP3 aus: {video_full_path}")
        subprocess.run(["ffmpeg", "-i", video_full_path, "-q:a", "0", "-map", "a", audio_full_path, "-y"],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except subprocess.CalledProcessError as e:
        logging.error(f"Fehler bei Audio-Konvertierung (ffmpeg): {e}")

    # Videolänge
    length_in_seconds = 0
    try:
        clip = VideoFileClip(video_full_path)
        length_in_seconds = int(clip.duration)
        clip.reader.close()
        if clip.audio:
            clip.audio.reader.close_proc()
    except Exception as e:
        logging.error(f"Fehler beim Bestimmen der Videolänge: {e}")

    # Erstellungsdatum
    try:
        creation_date = get_modification_date(video_full_path)
    except Exception as e:
        logging.error(f"Fehler beim Lesen des Dateidatums: {e}")
        creation_date = ""

    # Screenshots
    create_screenshot(video_full_path, screenshot_path_full)
    create_screenshot_thumbnail(screenshot_path_full, screenshot_thumb_path_full)

    # Storyboard
    create_storyboard(video_full_path, storyboard_path_full)
    create_storyboard_thumbnail(storyboard_path_full, storyboard_thumb_path_full)

    # Dateigrößen
    video_size = get_file_size(video_full_path)
    audio_size = get_file_size(audio_full_path)
    screenshot_size = get_file_size(screenshot_path_full)
    screenshot_thumb_size = get_file_size(screenshot_thumb_path_full)
    storyboard_size = get_file_size(storyboard_path_full)
    storyboard_thumb_size = get_file_size(storyboard_thumb_path_full)

    # Relative Pfade
    rel_video_path = relative_path_in_storage(video_full_path)
    rel_audio_path = relative_path_in_storage(audio_full_path)
    rel_screenshot_path = relative_path_in_storage(screenshot_path_full)
    rel_screenshot_thumb_path = relative_path_in_storage(screenshot_thumb_path_full)
    rel_storyboard_path = relative_path_in_storage(storyboard_path_full)
    rel_storyboard_thumb_path = relative_path_in_storage(storyboard_thumb_path_full)

    try:
        cursor.execute(f"""
            INSERT INTO {TABLE_NAME} (
                id, url, title, description, duration,
                view_count, like_count, repost_count, comment_count, uploader,
                channel, channel_id, channel_url, track, album, artists,
                timestamp, extractor, german_title, german_description,

                file_extension, creation_date, length_seconds,

                video_path, video_size,
                audio_path, audio_size,
                screenshot_path, screenshot_size,
                screenshot_thumbnail_path, screenshot_thumbnail_size,
                storyboard_path, storyboard_size,
                storyboard_thumbnail_path, storyboard_thumbnail_size,

                test_column
            )
            VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)
        """, (
            old_id,
            url,
            title,
            description,
            duration,
            view_count,
            like_count,
            repost_count,
            comment_count,
            uploader,

            channel,
            channel_id,
            channel_url,
            track,
            album,
            artists,
            timestamp,
            extractor,
            german_title,
            german_description,

            file_extension,
            creation_date,
            length_in_seconds,

            rel_video_path,
            video_size,

            rel_audio_path,
            audio_size,

            rel_screenshot_path,
            screenshot_size,

            rel_screenshot_thumb_path,
            screenshot_thumb_size,

            rel_storyboard_path,
            storyboard_size,

            rel_storyboard_thumb_path,
            storyboard_thumb_size,

            None  # <--- test_column
        ))
        connection.commit()
        logging.info(f"Erfolgreich in DB gespeichert: {url}")
    except Exception as e:
        logging.error(f"Fehler beim Speichern in neuer DB: {e}")
        traceback.print_exc()

def main():
    conn_new = sqlite3.connect(NEW_DB_PATH)
    cur_new = conn_new.cursor()

    # Drop + Create Table
    cur_new.executescript(SCHEMA)
    conn_new.commit()

    if not os.path.exists(OLD_DB_PATH):
        logging.error(f"Alte DB '{OLD_DB_PATH}' nicht gefunden. Abbruch.")
        conn_new.close()
        return

    conn_old = sqlite3.connect(OLD_DB_PATH)
    old_df = pd.read_sql_query("SELECT * FROM media_metadata", conn_old)
    conn_old.close()

    logging.info(f"Anzahl Datensätze in alter DB: {len(old_df)}")

    for row in old_df.itertuples():
        try:
            download_and_process_media(row, cur_new, conn_new)
        except Exception as e:
            logging.error(f"Allgemeiner Fehler bei Datensatz URL={row.url}: {e}")
            traceback.print_exc()

    conn_new.close()
    logging.info("Verarbeitung abgeschlossen. DB geschlossen.")

if __name__ == "__main__":
    main()
