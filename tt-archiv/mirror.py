#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import os
import sqlite3
import subprocess
import logging
import traceback
import time
from datetime import datetime
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
# Tabelle definieren (36 Spalten inkl. test_column)
###############################################################################
SCHEMA = f"""
DROP TABLE IF EXISTS {TABLE_NAME};

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
    length_seconds REAL,

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
    """Erzeugt sicheren Dateinamen (keine problematischen Zeichen, gekürzt)."""
    safe_title = ''.join(c for c in title if c.isalnum() or c in (' ', '-', '_')).strip()
    if len(safe_title) > max_length:
        safe_title = safe_title[:max_length]
    return safe_title

def get_modification_date(file_path):
    """Gibt das Modifikationsdatum einer Datei als String zurück oder ''."""
    if os.path.exists(file_path):
        stats = os.stat(file_path)
        return datetime.fromtimestamp(stats.st_mtime).strftime('%Y-%m-%d %H:%M:%S')
    return ""

def get_file_size(file_path):
    """Gibt Dateigröße in Byte zurück oder 0, falls Datei nicht existiert."""
    if os.path.exists(file_path):
        return os.path.getsize(file_path)
    return 0

def link_exists(cursor, link):
    """Prüft, ob URL bereits vorhanden ist. Gibt new_id oder None zurück."""
    cursor.execute(f"SELECT new_id FROM {TABLE_NAME} WHERE url=?", (link,))
    row = cursor.fetchone()
    return row[0] if row else None

def relative_path_in_storage(full_path):
    """Gibt relativen Pfad bezogen auf EXTERNAL_STORAGE_BASE zurück."""
    return os.path.relpath(full_path, EXTERNAL_STORAGE_BASE)

def wait_file(file_path, max_wait=3):
    """Wartet bis zu max_wait Sekunden, ob file_path angelegt wurde."""
    for _ in range(max_wait):
        if os.path.exists(file_path):
            return True
        time.sleep(1)
    return os.path.exists(file_path)

def create_screenshot(video_path, screenshot_full_path):
    """Screenshot bei Sekunde 1."""
    try:
        os.makedirs(os.path.dirname(screenshot_full_path), exist_ok=True)
        subprocess.run([
            "ffmpeg", "-i", video_path,
            "-ss", "00:00:01.000", "-vframes", "1",
            screenshot_full_path, "-y"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        logging.info(f"Screenshot erstellt: {screenshot_full_path}")
    except Exception as e:
        logging.error(f"Fehler beim Erstellen des Screenshots: {e}")
        traceback.print_exc()

def create_screenshot_thumbnail(screenshot_path, thumbnail_path):
    """Thumbnail aus Screenshot (halbierte Dimensionen)."""
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
    """Storyboard: 1 fps, tile=5x5, scale=320 Breite."""
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
    """Storyboard verkleinert (halbierte Dimensionen)."""
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
# INSERT/UPDATE in DB
###############################################################################
def insert_base_if_missing(cursor, connection, url, **kwargs):
    """
    Legt, falls nicht vorhanden, einen Eintrag in der DB an und gibt new_id zurück.
    Die restlichen Felder werden (erstmal) auf None/0 gesetzt,
    außer was in kwargs kommt.
    """
    existing = link_exists(cursor, url)
    if existing:
        logging.info(f"Datensatz existiert bereits new_id={existing} für URL={url}")
        return existing

    # Stelle sicher, dass wir 36 Werte liefern (genau so viele wie CREATE TABLE).
    # Wir setzen Standardwerte (None/0), überschreiben was in kwargs ist.
    # => Title, Uploader, etc. aus kwargs
    columns = [
        'id','url','title','description','duration','view_count','like_count','repost_count','comment_count',
        'uploader','channel','channel_id','channel_url','track','album','artists','timestamp','extractor',
        'german_title','german_description','file_extension','creation_date','length_seconds',
        'video_path','video_size','audio_path','audio_size','screenshot_path','screenshot_size',
        'screenshot_thumbnail_path','screenshot_thumbnail_size','storyboard_path','storyboard_size',
        'storyboard_thumbnail_path','storyboard_thumbnail_size','test_column'
    ]
    defaults = {
        'id': None,
        'url': None,
        'title': None,
        'description': None,
        'duration': 0.0,
        'view_count': 0,
        'like_count': 0,
        'repost_count': 0,
        'comment_count': 0,
        'uploader': None,
        'channel': None,
        'channel_id': None,
        'channel_url': None,
        'track': None,
        'album': None,
        'artists': None,
        'timestamp': 0,
        'extractor': None,
        'german_title': None,
        'german_description': None,
        'file_extension': None,
        'creation_date': None,
        'length_seconds': 0.0,
        'video_path': None,
        'video_size': 0,
        'audio_path': None,
        'audio_size': 0,
        'screenshot_path': None,
        'screenshot_size': 0,
        'screenshot_thumbnail_path': None,
        'screenshot_thumbnail_size': 0,
        'storyboard_path': None,
        'storyboard_size': 0,
        'storyboard_thumbnail_path': None,
        'storyboard_thumbnail_size': 0,
        'test_column': None
    }

    # Überschreibe defaults mit kwargs
    for k,v in kwargs.items():
        if k in defaults:
            defaults[k] = v

    values = [defaults[col] for col in columns]
    placeholders = ",".join(["?"]*len(columns))
    colnames = ",".join(columns)

    sql = f"INSERT INTO {TABLE_NAME} ({colnames}) VALUES ({placeholders})"
    cursor.execute(sql, values)
    connection.commit()
    new_id = cursor.lastrowid
    logging.info(f"Neuer Datensatz angelegt new_id={new_id} für URL={url}")
    return new_id

def update_db(cursor, connection, new_id, **kwargs):
    """
    Aktualisiert einzelne Spalten in media_info für den Datensatz new_id.
    kwargs: {spaltenname: wert}
    """
    if not kwargs:
        return
    set_clause = ", ".join([f"{k}=?" for k in kwargs.keys()])
    values = list(kwargs.values())
    values.append(new_id)
    sql = f"UPDATE {TABLE_NAME} SET {set_clause} WHERE new_id=?"
    cursor.execute(sql, values)
    connection.commit()
    logging.debug(f"UPDATE new_id={new_id} set {set_clause} -> {kwargs}")

###############################################################################
# Hauptverarbeitung
###############################################################################
def download_and_process_media(row, cursor, connection):
    """
    1) Minimalen Eintrag anlegen oder holen
    2) Download Video
    3) Audio extrahieren
    4) Screenshot + Thumbnail
    5) Storyboard + Thumbnail
    => je Schritt DB-Update
    """
    url = row.url
    # Werte aus alter DB
    old_id = getattr(row, 'id', None)
    title = getattr(row, 'title', None)
    description = getattr(row, 'description', None)
    duration = float(getattr(row, 'duration', 0) or 0)
    view_count = int(getattr(row, 'view_count', 0) or 0)
    like_count = int(getattr(row, 'like_count', 0) or 0)
    repost_count = int(getattr(row, 'repost_count', 0) or 0)
    comment_count = int(getattr(row, 'comment_count', 0) or 0)
    uploader = getattr(row, 'uploader', None)
    channel = getattr(row, 'channel', None)
    channel_id = getattr(row, 'channel_id', None)
    channel_url = getattr(row, 'channel_url', None)
    track = getattr(row, 'track', None)
    album = getattr(row, 'album', None)
    artists = getattr(row, 'artists', None)
    timestamp = int(getattr(row, 'timestamp', 0) or 0)
    extractor = getattr(row, 'extractor', None)
    german_title = getattr(row, 'german_title', None)
    german_description = getattr(row, 'german_description', None)

    # (1) Eintrag anlegen (falls nicht existiert)
    new_id = insert_base_if_missing(
        cursor, connection, url=url,
        id=old_id, title=title, description=description, duration=duration,
        view_count=view_count, like_count=like_count, repost_count=repost_count, comment_count=comment_count,
        uploader=uploader, channel=channel, channel_id=channel_id, channel_url=channel_url,
        track=track, album=album, artists=artists,
        timestamp=timestamp, extractor=extractor,
        german_title=german_title, german_description=german_description
    )

    # Pfade definieren
    safe_up = safe_filename(uploader or "unknown_uploader", 100)
    base_path = os.path.join(EXTERNAL_STORAGE_BASE, safe_up)
    os.makedirs(base_path, exist_ok=True)

    video_dir = os.path.join(base_path, VIDEO_SUBFOLDER)
    audio_dir = os.path.join(base_path, AUDIO_SUBFOLDER)
    screenshots_dir = os.path.join(base_path, SCREENSHOTS_SUBFOLDER)
    screenshot_thumbs_dir = os.path.join(base_path, SCREENSHOT_THUMBS_SUBFOLDER)
    storyboards_dir = os.path.join(base_path, STORYBOARDS_SUBFOLDER)
    storyboard_thumbs_dir = os.path.join(base_path, STORYBOARD_THUMBS_SUBFOLDER)

    for d in [video_dir, audio_dir, screenshots_dir, screenshot_thumbs_dir, storyboards_dir, storyboard_thumbs_dir]:
        os.makedirs(d, exist_ok=True)

    # dynamischen Titel via yt-dlp
    try:
        yt_result = subprocess.run(
            ["yt-dlp", "--get-filename", "-o", "%(title)s", url],
            capture_output=True, text=True, check=True
        )
        dyn_title = yt_result.stdout.strip()
        if dyn_title:
            title = dyn_title
    except subprocess.CalledProcessError:
        pass

    # 2) Video-Download
    safe_title = safe_filename(title or "", 150)
    file_extension = "mp4"
    video_full_path = os.path.join(video_dir, f"{safe_title}.{file_extension}")

    logging.info(f"[DL] Starte Download: {url}")
    try:
        subprocess.run(["yt-dlp", "-o", video_full_path, url],
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        logging.info(f"[DL] Fertig: {video_full_path}")
    except subprocess.CalledProcessError as e:
        logging.error(f"[DL] Fehler: {e}")
        return

    # DB update: file_extension, creation_date, video_path, video_size
    video_sz = get_file_size(video_full_path)
    cdate = get_modification_date(video_full_path)
    update_db(cursor, connection, new_id,
        file_extension=file_extension,
        creation_date=cdate,
        video_path=relative_path_in_storage(video_full_path),
        video_size=video_sz
    )

    # 3) Audio extrahieren
    audio_full_path = os.path.join(audio_dir, f"{safe_title}.mp3")
    try:
        logging.info(f"[Audio] Extrahiere Audio: {video_full_path}")
        subprocess.run([
            "ffmpeg", "-i", video_full_path,
            "-q:a", "0", "-map", "a", audio_full_path, "-y"
        ], stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        aud_sz = get_file_size(audio_full_path)
        update_db(cursor, connection, new_id,
            audio_path=relative_path_in_storage(audio_full_path),
            audio_size=aud_sz
        )
    except subprocess.CalledProcessError as e:
        logging.error(f"[Audio] Fehler: {e}")

    time.sleep(2)  # Warte, um FileNotFound zu minimieren

    # 4) Screenshot
    screenshot_path_full = os.path.join(screenshots_dir, f"{safe_title}_screenshot.jpg")
    create_screenshot(video_full_path, screenshot_path_full)
    time.sleep(1)

    if os.path.exists(screenshot_path_full):
        sc_sz = get_file_size(screenshot_path_full)
        update_db(cursor, connection, new_id,
            screenshot_path=relative_path_in_storage(screenshot_path_full),
            screenshot_size=sc_sz
        )
        # Screenshot-Thumbnail
        screenshot_thumb_path_full = os.path.join(screenshot_thumbs_dir, f"{safe_title}_screenshot_thumb.jpg")
        if wait_file(screenshot_path_full, 1):
            create_screenshot_thumbnail(screenshot_path_full, screenshot_thumb_path_full)
            time.sleep(1)
            if os.path.exists(screenshot_thumb_path_full):
                sc_tsz = get_file_size(screenshot_thumb_path_full)
                update_db(cursor, connection, new_id,
                    screenshot_thumbnail_path=relative_path_in_storage(screenshot_thumb_path_full),
                    screenshot_thumbnail_size=sc_tsz
                )
    else:
        logging.warning(f"Screenshot fehlt: {screenshot_path_full}")

    time.sleep(1)

    # 5) Storyboard
    storyboard_path_full = os.path.join(storyboards_dir, f"{safe_title}_storyboard.jpg")
    create_storyboard(video_full_path, storyboard_path_full)
    time.sleep(1)
    if os.path.exists(storyboard_path_full):
        sb_sz = get_file_size(storyboard_path_full)
        update_db(cursor, connection, new_id,
            storyboard_path=relative_path_in_storage(storyboard_path_full),
            storyboard_size=sb_sz
        )
        # Storyboard-Thumbnail
        storyboard_thumb_path_full = os.path.join(storyboard_thumbs_dir, f"{safe_title}_storyboard_thumb.jpg")
        if wait_file(storyboard_path_full, 1):
            create_storyboard_thumbnail(storyboard_path_full, storyboard_thumb_path_full)
            time.sleep(1)
            if os.path.exists(storyboard_thumb_path_full):
                sb_tsz = get_file_size(storyboard_thumb_path_full)
                update_db(cursor, connection, new_id,
                    storyboard_thumbnail_path=relative_path_in_storage(storyboard_thumb_path_full),
                    storyboard_thumbnail_size=sb_tsz
                )
    else:
        logging.warning(f"Storyboard fehlt: {storyboard_path_full}")

    logging.info(f"[OK] new_id={new_id} (URL={url}) fertig verarbeitet.")

def main():
    conn = sqlite3.connect(NEW_DB_PATH)
    cur = conn.cursor()

    # Neu anlegen
    cur.executescript(SCHEMA)
    conn.commit()

    if not os.path.exists(OLD_DB_PATH):
        logging.error(f"Alte DB '{OLD_DB_PATH}' fehlt.")
        conn.close()
        return

    conn_old = sqlite3.connect(OLD_DB_PATH)
    df = pd.read_sql_query("SELECT * FROM media_metadata", conn_old)
    conn_old.close()

    logging.info(f"Alte DB Datensätze: {len(df)}")

    for row in df.itertuples():
        try:
            download_and_process_media(row, cur, conn)
        except Exception as e:
            logging.error(f"Fehler bei URL={row.url}: {e}")
            traceback.print_exc()

    conn.close()
    logging.info("Fertig, DB geschlossen.")

if __name__ == "__main__":
    main()
