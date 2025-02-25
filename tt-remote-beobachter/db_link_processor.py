import os
import psycopg2
from psycopg2 import sql
from psycopg2.extras import DictCursor
from dotenv import load_dotenv
import logging
import subprocess
import json
import random
from datetime import datetime

logging.basicConfig(
    filename='tiktok_metadata_extraction.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filemode='a'
)

# .env laden (DB-Verbindungsdaten)
load_dotenv()
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")

def get_connection():
    """Verbindung zu PostgreSQL herstellen."""
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )

def init_db():
    """
    Tabellen links, media_metadata und media_time_series erstellen (sofern nicht vorhanden).
    Namen und Strukturen bleiben unverändert.
    """
    conn = get_connection()
    cur = conn.cursor()
    try:
        # Tabelle links
        cur.execute("""
        CREATE TABLE IF NOT EXISTS links (
            id SERIAL PRIMARY KEY,
            url TEXT NOT NULL,
            inserted_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
            processed BOOLEAN DEFAULT false
        );
        """)

        # Tabelle media_metadata
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

        # Tabelle media_time_series
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

        conn.commit()  # Einmaliges Commit für Tabellenerstellung
    finally:
        cur.close()
        conn.close()

def extract_metadata(url):
    """
    Metadaten via yt-dlp abrufen.
    '--flat-playlist' liefert ggf. eine 'entries'-Liste (z.B. bei Kanälen).
    """
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
    """
    Eintrag in 'media_time_series' vorbereiten (aktueller Stats-Snapshot).
    Keine Umbenennung oder Strukturänderung.
    """
    cur = conn.cursor()
    try:
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
    finally:
        cur.close()

def update_existing_video(conn, existing_data, new_data):
    """
    Vorhandenen Datensatz in 'media_metadata' aktualisieren
    und Eintrag in 'media_time_series' anlegen.
    Struktur unverändert.
    """
    cur = conn.cursor()
    try:
        old_view, old_like, old_repost, old_comment = existing_data

        new_view = new_data.get("view_count")
        new_like = new_data.get("like_count")
        new_repost = new_data.get("repost_count")
        new_comment = new_data.get("comment_count")

        diff_msg = (
            f"URL {new_data.get('url')} Stats-Update:\n"
            f"  Views:   alt={old_view}   neu={new_view}\n"
            f"  Likes:   alt={old_like}   neu={new_like}\n"
            f"  Reposts: alt={old_repost} neu={new_repost}\n"
            f"  Comments:alt={old_comment} neu={new_comment}"
        )
        logging.info(diff_msg)

        # Update in media_metadata
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

        # Neue Zeitreihe hinzufügen
        save_time_series(conn, new_data)

    finally:
        cur.close()

def save_video_metadata(conn, video):
    """
    Prüft, ob das Video in 'media_metadata' existiert. 
    Falls nein: neuer Datensatz. Falls ja: Update.
    In beiden Fällen Zeitreihen-Eintrag anlegen.
    Keine Strukturänderung.
    """
    cur = conn.cursor()
    try:
        cur.execute("""
            SELECT view_count, like_count, repost_count, comment_count
              FROM media_metadata
             WHERE url = %s
        """, (video.get("url"),))
        existing = cur.fetchone()

        if existing:
            update_existing_video(conn, existing, video)
        else:
            # Neuer Eintrag mit ON CONFLICT (id) verhindert Duplicate-Key-Abbruch
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
                    ON CONFLICT (id)
                    DO UPDATE
                    SET url = EXCLUDED.url,
                        title = EXCLUDED.title,
                        description = EXCLUDED.description,
                        duration = EXCLUDED.duration,
                        view_count = EXCLUDED.view_count,
                        like_count = EXCLUDED.like_count,
                        repost_count = EXCLUDED.repost_count,
                        comment_count = EXCLUDED.comment_count,
                        uploader = EXCLUDED.uploader,
                        uploader_id = EXCLUDED.uploader_id,
                        channel = EXCLUDED.channel,
                        channel_id = EXCLUDED.channel_id,
                        channel_url = EXCLUDED.channel_url,
                        track = EXCLUDED.track,
                        album = EXCLUDED.album,
                        artists = EXCLUDED.artists,
                        timestamp = EXCLUDED.timestamp,
                        extractor = EXCLUDED.extractor
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
                logging.info(f"Neuer Datensatz: {video.get('url')} (ON CONFLICT verarbeitet)")
                # Zeitreihe
                save_time_series(conn, video)
            except psycopg2.Error as e:
                logging.error(f"DB-Fehler bei Insert: {e}")
    finally:
        cur.close()

def process_playlist_metadata(conn, playlist_metadata):
    """
    Alle 'entries' in playlist_metadata durchgehen und
    in 'media_metadata' / 'media_time_series' aktualisieren.
    Keine Strukturänderungen.
    """
    if not playlist_metadata or "entries" not in playlist_metadata:
        logging.debug("Keine 'entries' in diesem JSON gefunden.")
        return
    for video in playlist_metadata["entries"]:
        save_video_metadata(conn, video)

def process_links_with_locking():
    """
    1) Lädt alle Links aus 'links' (unabhängig von 'processed').
    2) Mischt sie zufällig.
    3) Sperrt jeden Link per row-level locking (FOR UPDATE SKIP LOCKED) 
       und führt die Metadatenverarbeitung durch.
    4) Keine Endlosschleife -> Skript endet nach Durchlauf.
    """
    conn = get_connection()
    cur = conn.cursor(cursor_factory=DictCursor)

    # Alle Links laden
    cur.execute("""
        SELECT id, url
          FROM links
         ORDER BY id
    """)
    rows = cur.fetchall()

    # Falls keine Einträge, direkt beenden
    if not rows:
        logging.info("Keine Links in der Tabelle 'links' vorhanden. Skript beendet sich.")
        cur.close()
        conn.close()
        return

    logging.info(f"Starte Verarbeitung. Anzahl Links: {len(rows)}")
    # Zufällig mischen
    random.shuffle(rows)

    # Für jeden Link: Row-Level-Lock, extrahieren, verarbeiten
    for row in rows:
        link_id = row["id"]
        link_url = row["url"]

        logging.info(f"Versuche Link ID={link_id} via FOR UPDATE SKIP LOCKED zu sperren.")
        # Einzelner Versuch, Link per SKIP LOCKED zu holen
        cur.execute("""
            SELECT id, url
              FROM links
             WHERE id = %s
             FOR UPDATE SKIP LOCKED
        """, (link_id,))
        locked_row = cur.fetchone()

        if not locked_row:
            # Anderer Prozess hat das bereits gesperrt
            logging.debug(f"Link ID={link_id} ist bereits gesperrt. Überspringe.")
            continue

        # Jetzt haben wir exklusiven Zugriff -> Metadaten extrahieren
        logging.info(f"Bearbeite Link ID={link_id}, URL={link_url}")
        metadata_json = extract_metadata(link_url)

        if metadata_json:
            process_playlist_metadata(conn, metadata_json)
            # Beispiel: processed-Flag setzen, wenn alles geklappt hat
            cur.execute("UPDATE links SET processed = true WHERE id = %s", (link_id,))
            conn.commit()
            logging.info(f"Link {link_id} erfolgreich verarbeitet und gespeichert.")
        else:
            logging.warning(f"Keine Metadaten / Fehler für {link_url}")

    cur.close()
    conn.close()
    logging.info("Fertig mit dem Durchlauf. Skript beendet sich.")

def main():
    init_db()
    process_links_with_locking()

if __name__ == "__main__":
    main()
