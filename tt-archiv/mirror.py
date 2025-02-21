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
import csv

###############################################################################
# Logging
###############################################################################
logging.basicConfig(
    filename='media_processing.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

###############################################################################
# Pfade und Konfiguration
###############################################################################
METADATA_DB_PATH = os.path.join(os.getcwd(), "filtered_tiktok_media_metadata.db")
PROD_DB_DIR = os.path.join(os.getcwd(), "archiv")
os.makedirs(PROD_DB_DIR, exist_ok=True)
PROD_DB_PATH = os.path.join(PROD_DB_DIR, "filtered_tiktok_media.db")

EXTERNAL_STORAGE_BASE = "/mnt/HC_Volume_101955489/tricktok-archiv"

VIDEO_SUBFOLDER = "video"
AUDIO_SUBFOLDER = "audio"
SCREENSHOTS_SUBFOLDER = "screenshots"
SCREENSHOT_THUMBS_SUBFOLDER = "screenshot_thumbnails"
STORYBOARDS_SUBFOLDER = "storyboards"
STORYBOARD_THUMBS_SUBFOLDER = "storyboard_thumbnails"

TABLE_NAME = "media_info"
FAILED_LINKS_CSV = "fehlerlinks.csv"

###############################################################################
# CSV für fehlerhafte Links
###############################################################################
def log_failed_link(url, grund):
    """Schreibt URL + Fehlergrund in eine CSV."""
    existierte_schon = os.path.exists(FAILED_LINKS_CSV)
    with open(FAILED_LINKS_CSV, mode="a", encoding="utf-8", newline="") as csvfile:
        writer = csv.writer(csvfile, delimiter=";")
        if not existierte_schon:
            writer.writerow(["zeitpunkt", "url", "grund"])
        writer.writerow([datetime.now().strftime('%Y-%m-%d %H:%M:%S'), url, grund])
    logging.warning(f"Fehlerhafter Link protokolliert: {url} - {grund}")

###############################################################################
# Hilfsfunktionen
###############################################################################
def safe_filename(title, max_length=200):
    """Sicheren Dateinamen erzeugen."""
    if not title:
        return "unbekannt"
    clean = "".join(c for c in title if c.isalnum() or c in (' ', '-', '_')).strip()
    return clean[:max_length] if len(clean) > max_length else clean

def get_file_size(file_path):
    """Dateigröße oder 0."""
    if os.path.exists(file_path):
        return os.path.getsize(file_path)
    return 0

def link_exists(cursor, url):
    """Überprüfen, ob URL schon vorhanden."""
    cursor.execute(f"SELECT new_id FROM {TABLE_NAME} WHERE url=?", (url,))
    row = cursor.fetchone()
    return row[0] if row else None

###############################################################################
# DB-Operationen
###############################################################################
def ensure_gallery_dl_output_column(cursor):
    """
    Prüft, ob 'gallery_dl_output' existiert.
    Falls nein -> ALTER TABLE zum Anlegen einer TEXT-Spalte.
    """
    cursor.execute(f"PRAGMA table_info({TABLE_NAME});")
    columns = [row[1] for row in cursor.fetchall()]
    if "gallery_dl_output" not in columns:
        sql = f"ALTER TABLE {TABLE_NAME} ADD COLUMN gallery_dl_output TEXT"
        cursor.execute(sql)
        logging.info(f"Spalte 'gallery_dl_output' in {TABLE_NAME} angelegt.")

def insert_placeholder(cursor, connection, url, **kwargs):
    """
    Legt eine Zeile mit Metadaten in media_info an.
    """
    cursor.execute(f"PRAGMA table_info({TABLE_NAME});")
    existing_columns = [row[1] for row in cursor.fetchall()]

    defaults = {}
    for col in existing_columns:
        defaults[col] = None

    defaults["url"] = url
    # Metadaten, falls Spalten existieren
    for key in ["id", "title", "description", "duration", "view_count", "like_count",
                "repost_count", "comment_count", "uploader", "channel", "channel_id",
                "channel_url", "track", "album", "artists", "timestamp", "extractor",
                "german_title", "german_description"]:
        if key in defaults:
            defaults[key] = kwargs.get(key, defaults[key])

    columns_for_insert = []
    placeholders = []
    values = []
    for col in existing_columns:
        columns_for_insert.append(col)
        placeholders.append("?")
        values.append(defaults[col])

    sql = f"INSERT INTO {TABLE_NAME} ({','.join(columns_for_insert)}) VALUES ({','.join(placeholders)})"
    cursor.execute(sql, values)
    connection.commit()

    new_id = cursor.lastrowid
    logging.info(f"Neue Metadatenzeile new_id={new_id} URL={url} erstellt.")
    return new_id

def update_db(cursor, connection, new_id, **kwargs):
    """Spalten updaten."""
    if not kwargs:
        return
    cursor.execute(f"PRAGMA table_info({TABLE_NAME});")
    valid_cols = [row[1] for row in cursor.fetchall()]

    set_fragments = []
    values = []
    for k, v in kwargs.items():
        if k in valid_cols:
            set_fragments.append(f"{k}=?")
            values.append(v)

    if not set_fragments:
        return

    values.append(new_id)
    sql = f"UPDATE {TABLE_NAME} SET {', '.join(set_fragments)} WHERE new_id=?"
    cursor.execute(sql, values)
    connection.commit()

###############################################################################
# gallery-dl Fallback
###############################################################################
def fallback_gallery_dl(url):
    """
    Ruft gallery-dl auf, ohne Pfadangabe, d.h. Output landet im aktuellen Verzeichnis.
    Gibt stdout+stderr als multiline-String zurück.
    """
    logging.info(f"[FALLBACK] Starte gallery-dl für URL={url}")
    try:
        result = subprocess.run(["gallery-dl", url],
                                stdout=subprocess.PIPE,
                                stderr=subprocess.PIPE,
                                text=True,
                                check=True)
        # Alles zusammenfassen
        combined = result.stdout + "\n" + result.stderr
        logging.info("[FALLBACK] gallery-dl erfolgreich!")
        return combined.strip()
    except subprocess.CalledProcessError as e:
        # Falls Fehler => teile stdout/ stderr oder e Ausgabe
        logging.error(f"[FALLBACK] gallery-dl fehlgeschlagen: {e}")
        partial = (e.stdout or "") + "\n" + (e.stderr or "")
        return partial.strip()

###############################################################################
# Hauptprozess
###############################################################################
def download_and_process_media(row, cursor, connection):
    url = getattr(row, "url", None)
    if not url:
        return

    # Duplikat?
    if link_exists(cursor, url):
        logging.info(f"Überspringe, URL={url} bereits vorhanden.")
        return

    # Metadaten aus dem Row
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

    # Platzhalter in DB
    main_id = insert_placeholder(
        cursor, connection,
        url=url, id=old_id, title=title, description=description, duration=duration,
        view_count=view_count, like_count=like_count, repost_count=repost_count,
        comment_count=comment_count, uploader=uploader, channel=channel, channel_id=channel_id,
        channel_url=channel_url, track=track, album=album, artists=artists, timestamp=timestamp,
        extractor=extractor, german_title=german_title, german_description=german_description
    )

    # Ordner anlegen
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

    # Optional: dynamischer Titel
    try:
        dyn = subprocess.run(["yt-dlp", "--get-filename", "-o", "%(title)s", url],
                             stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                             text=True, check=True)
        if dyn.stdout.strip():
            title = dyn.stdout.strip()
    except subprocess.CalledProcessError:
        pass

    safe_title = safe_filename(title or "", 150)
    video_path = os.path.join(video_dir, f"{safe_title}.mp4")

    # Download
    try:
        logging.info(f"[DL] Starte Download: {url}")
        subprocess.run(["yt-dlp", "-o", video_path, url],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                       text=True, check=True)
        logging.info(f"[DL] ok: {video_path}")
    except subprocess.CalledProcessError as e:
        # => fallback
        logging.error(f"yt-dlp-Fehler: {url} => {str(e)}")
        log_failed_link(url, f"yt-dlp-Fehler: {e}")
        gall_out = fallback_gallery_dl(url)
        update_db(cursor, connection, main_id, gallery_dl_output=gall_out)
        return

    # Prüfen ob 0 Byte
    vid_size = get_file_size(video_path)
    if vid_size == 0:
        logging.error(f"Videodatei 0 Byte: {video_path}")
        log_failed_link(url, "Video 0 Byte (yt-dlp)")
        gall_out = fallback_gallery_dl(url)
        update_db(cursor, connection, main_id, gallery_dl_output=gall_out)
        return

    # In DB
    update_db(cursor, connection, main_id,
              file_extension="mp4",
              creation_date=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
              video_path=os.path.relpath(video_path, EXTERNAL_STORAGE_BASE),
              video_size=vid_size)

    # Audio
    audio_path = os.path.join(audio_dir, f"{safe_title}.mp3")
    try:
        subprocess.run(["ffmpeg", "-i", video_path, "-q:a", "0", "-map", "a", audio_path, "-y"],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        aud_size = get_file_size(audio_path)
        update_db(cursor, connection, main_id,
                  audio_path=os.path.relpath(audio_path, EXTERNAL_STORAGE_BASE),
                  audio_size=aud_size)
    except subprocess.CalledProcessError as e:
        logging.error(f"Audio-Fehler: {url} => {str(e)}")
        log_failed_link(url, f"Audio-Fehler: {str(e)}")
        gall_out = fallback_gallery_dl(url)
        update_db(cursor, connection, main_id, gallery_dl_output=gall_out)
        return

    # Screenshot
    screenshot_full = os.path.join(screenshots_dir, f"{safe_title}_screenshot.jpg")
    try:
        subprocess.run(["ffmpeg", "-i", video_path,
                        "-ss", "00:00:01.000", "-vframes", "1",
                        screenshot_full, "-y"],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        sc_sz = get_file_size(screenshot_full)
        if sc_sz > 0:
            update_db(cursor, connection, main_id,
                      screenshot_path=os.path.relpath(screenshot_full, EXTERNAL_STORAGE_BASE),
                      screenshot_size=sc_sz)

            # Thumb
            screenshot_thumb = os.path.join(screenshot_thumbs_dir, f"{safe_title}_screenshot_thumb.jpg")
            subprocess.run(["ffmpeg", "-i", screenshot_full,
                            "-vf", "scale=iw/2:ih/2", screenshot_thumb, "-y"],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
            sc_tn_sz = get_file_size(screenshot_thumb)
            if sc_tn_sz > 0:
                update_db(cursor, connection, main_id,
                          screenshot_thumbnail_path=os.path.relpath(screenshot_thumb, EXTERNAL_STORAGE_BASE),
                          screenshot_thumbnail_size=sc_tn_sz)
        else:
            logging.warning("Screenshot hat 0 Byte.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Screeenshot-Fehler: {url} => {str(e)}")
        log_failed_link(url, f"Screeenshot-Fehler: {str(e)}")
        gall_out = fallback_gallery_dl(url)
        update_db(cursor, connection, main_id, gallery_dl_output=gall_out)
        return

    # Storyboard
    storyboard_path = os.path.join(storyboards_dir, f"{safe_title}_storyboard.jpg")
    try:
        subprocess.run(["ffmpeg", "-i", video_path,
                        "-vf", "fps=1,scale=320:-1,tile=5x5",
                        "-frames:v", "1", storyboard_path, "-y"],
                       stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
        sb_sz = get_file_size(storyboard_path)
        if sb_sz > 0:
            update_db(cursor, connection, main_id,
                      storyboard_path=os.path.relpath(storyboard_path, EXTERNAL_STORAGE_BASE),
                      storyboard_size=sb_sz)
            # SB-Thumb
            storyboard_thumb = os.path.join(storyboard_thumbs_dir, f"{safe_title}_storyboard_thumb.jpg")
            subprocess.run(["ffmpeg", "-i", storyboard_path,
                            "-vf", "scale=iw/2:ih/2", storyboard_thumb, "-y"],
                           stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, check=True)
            sbt_sz = get_file_size(storyboard_thumb)
            if sbt_sz > 0:
                update_db(cursor, connection, main_id,
                          storyboard_thumbnail_path=os.path.relpath(storyboard_thumb, EXTERNAL_STORAGE_BASE),
                          storyboard_thumbnail_size=sbt_sz)
        else:
            logging.warning("Storyboard 0 Byte.")
    except subprocess.CalledProcessError as e:
        logging.error(f"Storyboard-Fehler: {url} => {str(e)}")
        log_failed_link(url, f"Storyboard-Fehler: {str(e)}")
        gall_out = fallback_gallery_dl(url)
        update_db(cursor, connection, main_id, gallery_dl_output=gall_out)
        return

    logging.info(f"[OK] new_id={main_id} (URL={url}) fertig verarbeitet.")

def main():
    if not os.path.exists(PROD_DB_PATH):
        logging.error(f"Produktionsdatenbank {PROD_DB_PATH} fehlt!")
        return

    try:
        conn_prod = sqlite3.connect(PROD_DB_PATH)
        cur_prod = conn_prod.cursor()
    except sqlite3.Error as e:
        logging.error(f"Fehler beim Öffnen PROD DB: {e}")
        return

    # Spalte anlegen (falls fehlt)
    ensure_gallery_dl_output_column(cur_prod)

    if not os.path.exists(METADATA_DB_PATH):
        logging.error(f"Metadatenbank {METADATA_DB_PATH} fehlt!")
        conn_prod.close()
        return

    try:
        conn_meta = sqlite3.connect(METADATA_DB_PATH)
        df = pd.read_sql_query("SELECT * FROM media_metadata", conn_meta)
        conn_meta.close()
    except sqlite3.Error as e:
        logging.error(f"Fehler beim Lesen Metadatenbank: {e}")
        conn_prod.close()
        return

    logging.info(f"Starte Verarbeitung: {len(df)} Datensätze")

    zaehler = 0
    for row in df.itertuples():
        try:
            download_and_process_media(row, cur_prod, conn_prod)
            zaehler += 1
        except Exception as e:
            logging.error(f"Fehler bei {row.url}: {e}")
            traceback.print_exc()
            log_failed_link(getattr(row, "url", "unbekannt"), f"Unbekannter Fehler: {e}")

    conn_prod.close()
    logging.info(f"Fertig. Verarbeitete Datensätze: {zaehler}")

if __name__ == "__main__":
    main()
