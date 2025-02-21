#!/usr/bin/env python3
# Keine Personalpronomen in Kommentaren oder Texten.
# Skript: Metadaten-Crawler für TikTok-ähnliche Links.
# Verwendet yt-dlp, um Metadaten abzurufen.
# Neu: existierende Datensätze in media_metadata aktualisieren (inkl. Log-Ausgabe alter/neuer Stats).
# Schreibt Zeitreihen-Snapshots in media_time_series.
# Verbindungsdaten aus .env.
# Logrotation: maximal ~20 MB pro Logdatei.
# Parallele Verarbeitung via SELECT ... FOR UPDATE SKIP LOCKED.

import os
import json
import logging
import subprocess
import psycopg2
from psycopg2 import sql
from psycopg2.pool import SimpleConnectionPool
from logging.handlers import RotatingFileHandler
from datetime import datetime
from dotenv import load_dotenv

# Begrüßung
print("=== Start des TrickTok-Insert-Skripts (mit Update-Log) ===")

# Log-Setup (RotatingFileHandler)
handler = RotatingFileHandler(
    'tiktok_metadata_extraction.log',
    maxBytes=20_000_000,  # 20 MB
    backupCount=5
)
formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
handler.setFormatter(formatter)
root_logger = logging.getLogger()
root_logger.setLevel(logging.DEBUG)
root_logger.addHandler(handler)

# .env laden
load_dotenv()
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")

# Verbindungspool einrichten
try:
    connection_pool = SimpleConnectionPool(
        1, 20,
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        connect_timeout=60,               # 60 Sek Timeout
        options='-c statement_timeout=300000'  # 300k ms = 5 Min
    )
    logging.info("Pool erfolgreich erstellt.")
except Exception as e:
    logging.error("Fehler beim Erstellen des Verbindungspools: %s", e)
    raise SystemExit("Kritischer Fehler: Pool konnte nicht erstellt werden.")

def get_connection():
    """
    Verbindung aus dem Pool holen.
    """
    try:
        return connection_pool.getconn()
    except Exception as ex:
        logging.error("Fehler beim Holen einer Verbindung aus dem Pool: %s", ex)
        raise

def release_connection(conn):
    """
    Verbindung zurück in den Pool geben.
    """
    try:
        connection_pool.putconn(conn)
    except Exception as ex:
        logging.warning("Fehler beim Zurückgeben einer Verbindung: %s", ex)

def extract_metadata(url_link):
    """
    Aufruf von yt-dlp:
    --flat-playlist, --dump-single-json
    Rückgabe: Dict oder None.
    """
    try:
        result = subprocess.run(
            ["yt-dlp", "--flat-playlist", "--dump-single-json", url_link],
            capture_output=True,
            text=True,
            timeout=120
        )
        if result.returncode == 0:
            data = json.loads(result.stdout)
            logging.debug("Metadaten für '%s' empfangen.", url_link)
            return data
        else:
            logging.error("Fehler bei yt-dlp für '%s': %s", url_link, result.stderr)
            return None
    except subprocess.TimeoutExpired:
        logging.error("Timeout bei yt-dlp für '%s'", url_link)
        return None
    except Exception as e:
        logging.error("Allgemeiner Fehler bei yt-dlp für '%s': %s", url_link, e)
        return None

def save_time_series(cur, video):
    """
    Neuer Snapshot in media_time_series.
    """
    try:
        cur.execute(sql.SQL("""
            INSERT INTO media_time_series (
                url, view_count, like_count, repost_count, comment_count, recorded_at
            ) VALUES (%s, %s, %s, %s, %s, %s)
        """), [
            video.get("url"),
            video.get("view_count"),
            video.get("like_count"),
            video.get("repost_count"),
            video.get("comment_count"),
            datetime.now()
        ])
    except Exception as e:
        logging.error("Fehler beim INSERT in media_time_series für '%s': %s", video.get("url"), e)
        raise

def update_existing_video(cur, existing_data, new_data):
    """
    Existierenden Datensatz in media_metadata aktualisieren.
    Zeitreihe in media_time_series protokollieren.
    Log-Ausgabe: alter vs. neuer Wert (Views, Likes, Reposts, Comments).
    """
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
            ", ".join(new_data.get("artists", []) or []),
            new_data.get("timestamp"),
            new_data.get("extractor"),
            new_data.get("url")
        ))

        # Zeitreihen-Eintrag
        save_time_series(cur, new_data)
    except Exception as e:
        logging.error("Fehler beim UPDATE in media_metadata für '%s': %s", new_data.get("url"), e)
        raise

def save_video_metadata(conn, video):
    """
    Besteht schon? => Update
    Sonst => Insert
    + Zeitreihe
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
            update_existing_video(cur, existing, video)
        else:
            # Neuer Datensatz
            try:
                artists_list = video.get("artists", [])
                if not isinstance(artists_list, list):
                    artists_list = []
                artists_str = ", ".join(artists_list)

                cur.execute(sql.SQL("""
                    INSERT INTO media_metadata (
                        id, url, title, description, duration,
                        view_count, like_count, repost_count, comment_count,
                        uploader, uploader_id, channel, channel_id,
                        channel_url, track, album, artists,
                        timestamp, extractor
                    )
                    VALUES (%s, %s, %s, %s, %s,
                            %s, %s, %s, %s,
                            %s, %s, %s, %s,
                            %s, %s, %s, %s,
                            %s, %s)
                """), [
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
                    artists_str,
                    video.get("timestamp"),
                    video.get("extractor")
                ])
                logging.info("Neuer Datensatz erstellt für '%s'", video.get("url"))
                save_time_series(cur, video)
            except Exception as e:
                logging.error("Fehler beim INSERT in media_metadata für '%s': %s", video.get("url"), e)
                raise
    finally:
        cur.close()

def process_playlist_metadata(conn, playlist):
    """
    JSON mit 'entries' => Schleife => save_video_metadata()
    """
    if not playlist or "entries" not in playlist:
        logging.debug("Keine 'entries' im JSON.")
        return
    for vid in playlist["entries"]:
        save_video_metadata(conn, vid)

def process_links_with_locking():
    """
    Liest links (SELECT ... FOR UPDATE SKIP LOCKED).
    Für jeden Link => Metadaten abrufen => save_video_metadata()
    => Commit
    """
    conn = get_connection()
    try:
        cur = conn.cursor()
        cur.execute("""
            SELECT id, url
              FROM links
             ORDER BY id
             FOR UPDATE SKIP LOCKED
        """)
        rows = cur.fetchall()
        logging.info("%d Zeilen gelockt. Verarbeitung startet ...", len(rows))

        for (link_id, link_url) in rows:
            logging.info("Verarbeitung: Link ID=%s, URL=%s", link_id, link_url)
            metadata_json = extract_metadata(link_url)
            if metadata_json:
                process_playlist_metadata(conn, metadata_json)
                conn.commit()
                logging.info("Verarbeitung für Link %s abgeschlossen.", link_id)
            else:
                logging.warning("Keine Metadaten / Fehler für %s", link_url)
                # Nach Bedarf: rollback oder weitermachen
    finally:
        cur.close()
        release_connection(conn)
        logging.info("Fertig mit dem locked-Durchlauf.")

def main():
    logging.info("Start von main() im TrickTok-Insert-Skript (mit Updates).")
    process_links_with_locking()
    logging.info("Ende von main().")

if __name__ == "__main__":
    main()
