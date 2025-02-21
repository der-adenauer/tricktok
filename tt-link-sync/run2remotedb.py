import os
import psycopg2
from psycopg2 import sql
from dotenv import load_dotenv
import logging
import subprocess
import json
from datetime import datetime

logging.basicConfig(
    filename='tiktok_metadata_extraction.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filemode='a'
)

# .env laden
load_dotenv()
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")

def get_connection():
    """Stellt eine Verbindung zu PostgreSQL her."""
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )
    return conn

def init_db():
    """Erstellt (sofern nicht vorhanden) die Tabellen."""
    conn = get_connection()
    cur = conn.cursor()
    try:
        cur.execute("""
        CREATE TABLE IF NOT EXISTS links (
            id SERIAL PRIMARY KEY,
            url TEXT NOT NULL,
            inserted_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
            processed BOOLEAN DEFAULT false
        );
        """)
        cur.execute("""
        CREATE TABLE IF NOT EXISTS media_metadata (
            id TEXT PRIMARY KEY,
            url TEXT NOT NULL,
            title TEXT,
            description TEXT,
            duration INTEGER,
            view_count INTEGER,
            like_count INTEGER,
            repost_count INTEGER,
            comment_count INTEGER,
            uploader TEXT,
            uploader_id TEXT,
            channel TEXT,
            channel_id TEXT,
            channel_url TEXT,
            track TEXT,
            album TEXT,
            artists TEXT,
            timestamp BIGINT,
            extractor TEXT
        );
        """)
        cur.execute("""
        CREATE TABLE IF NOT EXISTS media_time_series (
            series_id SERIAL PRIMARY KEY,
            url TEXT NOT NULL,
            view_count INTEGER,
            like_count INTEGER,
            repost_count INTEGER,
            comment_count INTEGER,
            recorded_at TIMESTAMP WITH TIME ZONE DEFAULT now()
        );
        """)
        conn.commit()
    finally:
        cur.close()
        conn.close()

def extract_metadata(url):
    """Extrahiert Metadaten via yt-dlp."""
    try:
        result = subprocess.run(
            ["yt-dlp", "--flat-playlist", "--dump-single-json", url],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            return json.loads(result.stdout)
        else:
            logging.error(f"Fehler beim Abrufen von {url}: {result.stderr}")
            return None
    except Exception as e:
        logging.error(f"Fehler beim Abrufen von {url}: {e}")
        return None

def save_time_series(conn, video):
    """Fügt Eintrag in die Zeitreihen-Tabelle ein."""
    cur = conn.cursor()
    cur.execute("""
        INSERT INTO media_time_series (
            url, view_count, like_count, repost_count, comment_count, recorded_at
        ) VALUES (%s, %s, %s, %s, %s, %s)
    """, (
        video.get("url"),
        video.get("view_count"),
        video.get("like_count"),
        video.get("repost_count"),
        video.get("comment_count"),
        datetime.now()
    ))
    conn.commit()
    cur.close()

def update_existing_video(conn, existing_data, new_data):
    """Aktualisiert vorhandenen Datensatz und legt Zeitreihen-Eintrag an."""
    cur = conn.cursor()
    old_view, old_like, old_repost, old_comment = existing_data

    new_view = new_data.get("view_count")
    new_like = new_data.get("like_count")
    new_repost = new_data.get("repost_count")
    new_comment = new_data.get("comment_count")

    diff_msg = (
        f"URL {new_data.get('url')} Stats-Update: "
        f"Views alt={old_view}, neu={new_view} | "
        f"Likes alt={old_like}, neu={new_like}"
    )
    logging.info(diff_msg)

    cur.execute("""
        UPDATE media_metadata
           SET title = %s,
               description = %s,
               duration = %s,
               view_count = %s,
               like_count = %s,
               repost_count = %s,
               comment_count = %s,
               uploader = %s,
               uploader_id = %s,
               channel = %s,
               channel_id = %s,
               channel_url = %s,
               track = %s,
               album = %s,
               artists = %s,
               timestamp = %s,
               extractor = %s
         WHERE url = %s
    """, (
        new_data.get("title"),
        new_data.get("description"),
        new_data.get("duration"),
        new_view,
        new_like,
        new_repost,
        new_comment,
        new_data.get("uploader"),
        new_data.get("uploader_id"),
        new_data.get("channel"),
        new_data.get("channel_id"),
        new_data.get("channel_url"),
        new_data.get("track"),
        new_data.get("album"),
        ", ".join(new_data.get("artists", [])),
        new_data.get("timestamp"),
        new_data.get("extractor"),
        new_data.get("url")
    ))
    conn.commit()
    cur.close()

def save_video_metadata(conn, video):
    """Legt neuen oder aktualisierten Datensatz an + Zeitreihe."""
    cur = conn.cursor()
    cur.execute("""
        SELECT view_count, like_count, repost_count, comment_count
          FROM media_metadata
         WHERE url = %s
    """, (video.get("url"),))
    existing = cur.fetchone()

    if existing:
        update_existing_video(conn, existing, video)
        save_time_series(conn, video)
    else:
        # Neuer Eintrag
        try:
            cur.execute("""
                INSERT INTO media_metadata (
                    id, url, title, description, duration,
                    view_count, like_count, repost_count, comment_count,
                    uploader, uploader_id, channel, channel_id,
                    channel_url, track, album, artists,
                    timestamp, extractor
                ) VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s,
                          %s, %s, %s, %s,
                          %s, %s, %s, %s,
                          %s, %s)
            """, (
                video.get("id"),
                video.get("url"),
                video.get("title"),
                video.get("description"),
                video.get("duration"),
                video.get("view_count"),
                video.get("like_count"),
                video.get("repost_count"),
                video.get("comment_count"),
                video.get("uploader"),
                video.get("uploader_id"),
                video.get("channel"),
                video.get("channel_id"),
                video.get("channel_url"),
                video.get("track"),
                video.get("album"),
                ", ".join(video.get("artists", [])),
                video.get("timestamp"),
                video.get("extractor")
            ))
            conn.commit()
            logging.info(f"Neuer Datensatz: {video.get('url')}")
            save_time_series(conn, video)
        except psycopg2.Error as e:
            logging.error(f"DB-Fehler bei Insert: {e}")
        finally:
            cur.close()

def process_playlist_metadata(conn, playlist_metadata):
    """Macht save_video_metadata() für alle Videos in 'entries'."""
    if not playlist_metadata or "entries" not in playlist_metadata:
        logging.debug("Keine Videos gefunden.")
        return
    for video in playlist_metadata["entries"]:
        save_video_metadata(conn, video)

def process_links(file_name="links.txt"):
    """Hauptlogik: links.txt lesen, Metadaten abfragen, in PostgreSQL speichern."""
    if not os.path.exists(file_name):
        logging.error(f"Datei {file_name} nicht gefunden!")
        return

    with open(file_name, "r", encoding="utf-8") as f:
        links = [l.strip() for l in f if l.strip()]

    logging.info(f"Gefundene Links: {len(links)}")

    conn = get_connection()
    for idx, url in enumerate(links, start=1):
        logging.info(f"URL {idx}/{len(links)}: {url}")
        playlist_metadata = extract_metadata(url)
        if playlist_metadata:
            process_playlist_metadata(conn, playlist_metadata)
        else:
            logging.warning(f"Keine Metadaten für {url}")

    conn.close()
    logging.info("Vorgang abgeschlossen.")

if __name__ == "__main__":
    init_db()
    process_links()
