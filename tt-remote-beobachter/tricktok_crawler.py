#!/usr/bin/env python3
# Skript zum Einfügen von Metadaten basierend auf Links in einer PostgreSQL-Datenbank
# Keine Personalpronomen in Kommentaren oder Texten.
# Dient einer parallelen Verarbeitung mit vielen Clients.
# Nur INSERT und SELECT nutzen (keine Updates, keine Tabellenanlage).
# Verbindungsdaten aus .env.
# Logrotation verwenden, damit Logdatei nicht größer als 20 MB wird.
# Keine weiteren Ausgaben in der Shell, außer einer Begrüßungszeile.

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
print("=== Start des TrickTok-Insert-Skripts ===")

# Log-Setup (RotatingFileHandler, um maximal ~20 MB pro Logdatei zu behalten)
handler = RotatingFileHandler(
    'tiktok_metadata_extraction.log',
    maxBytes=20_000_000,  # 20 MB
    backupCount=5         # mehrere alte Log-Dateien vorhalten
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

# Verbindungspool einrichten (mindestens 1, maximal z.B. 20 gleichzeitige Verbindungen)
# connect_timeout etwas höher, um Verbindungsabbrüche abzufangen
try:
    connection_pool = SimpleConnectionPool(
        1, 20,
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS,
        connect_timeout=60,             # 60 Sekunden Timeout
        options='-c statement_timeout=300000'  # 300.000 ms = 5 Minuten
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
    Aufruf von yt-dlp mit '--flat-playlist' und '--dump-single-json'.
    Rückgabe der Metadaten als Python-Objekt (Dictionary oder None).
    """
    try:
        result = subprocess.run(
            ["yt-dlp", "--flat-playlist", "--dump-single-json", url_link],
            capture_output=True,
            text=True,
            timeout=120  # Separater Timeout für yt-dlp
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

def insert_into_media_metadata(cur, video):
    """
    INSERT in media_metadata.
    Keine Updates, nur Einfügen.
    Doppelter Primärschlüssel wird ignoriert, wenn id schon existiert.
    """
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
            VALUES (
                %s, %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s, %s, %s,
                %s, %s
            )
            ON CONFLICT (id) DO NOTHING
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
        logging.debug("INSERT in media_metadata für '%s' durchgeführt.", video.get("url"))
    except Exception as e:
        logging.error("Fehler beim INSERT in media_metadata für '%s': %s", video.get("url"), e)

def insert_into_media_time_series(cur, video):
    """
    INSERT in media_time_series: Snapshots (view_count usw.) speichern.
    Immer ein neuer Zeileneintrag.
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
        logging.debug("INSERT in media_time_series für '%s' durchgeführt.", video.get("url"))
    except Exception as e:
        logging.error("Fehler beim INSERT in media_time_series für '%s': %s", video.get("url"), e)

def process_single_video(cur, video):
    """
    Einzelnes Video in media_metadata und media_time_series einfügen.
    Kein Update für bestehende Datensätze.
    """
    insert_into_media_metadata(cur, video)
    insert_into_media_time_series(cur, video)

def process_playlist_metadata(conn, playlist):
    """
    playlist kann ein JSON-Objekt mit 'entries' sein.
    Für jedes Entry INSERTs in media_metadata und media_time_series.
    """
    if not playlist or "entries" not in playlist:
        logging.debug("Keine 'entries' im JSON gefunden.")
        return
    
    cur = conn.cursor()
    try:
        for video in playlist["entries"]:
            process_single_video(cur, video)
    finally:
        cur.close()

def process_links_with_locking():
    """
    Links-Tabelle auslesen. ID und URL werden per row-level locking geholt:
    SELECT ... FOR UPDATE SKIP LOCKED.
    Nur SELECT und INSERT Rechte erforderlich.
    Keine UPDATE-Befehle in diesem Skript.
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
        logging.info("%d Zeilen gelockt. Verarbeitung starten ...", len(rows))

        for (link_id, link_url) in rows:
            logging.info("Verarbeitung: Link ID=%s, URL=%s", link_id, link_url)
            metadata_json = extract_metadata(link_url)
            if metadata_json:
                process_playlist_metadata(conn, metadata_json)
                conn.commit()  # Abschließen der Inserts
                logging.info("Verarbeitung für Link %s abgeschlossen.", link_id)
            else:
                logging.warning("Keine Metadaten / Fehler für %s", link_url)
    except Exception as e:
        logging.error("Fehler in process_links_with_locking: %s", e)
    finally:
        cur.close()
        release_connection(conn)
        logging.info("Fertig mit dem locked-Durchlauf.")

def main():
    logging.info("Start von main() im TrickTok-Insert-Skript.")
    # init_db() entfernt, da keine Tabellenerzeugung erwünscht.
    process_links_with_locking()
    logging.info("Beendigung von main().")

if __name__ == "__main__":
    main()
