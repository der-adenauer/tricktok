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

# Umgebung einlesen, z.B. aus .env
load_dotenv()
DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")

def get_connection():
    """
    Stellt Verbindung zu PostgreSQL her.
    """
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )

def extract_metadata(url):
    """
    Ruft Metadaten via yt-dlp ab.
    '--flat-playlist' liefert ggf. 'entries' bei Kanälen/Playlists.
    """
    try:
        result = subprocess.run(
            ["yt-dlp", "--flat-playlist", "--dump-single-json", url],
            capture_output=True,
            text=True
        )
        if result.returncode == 0 and result.stdout.strip():
            return json.loads(result.stdout)
        else:
            logging.error(f"Fehler beim Abruf von {url}: {result.stderr}")
            return None
    except Exception as e:
        logging.error(f"Fehler beim Abruf von {url}: {e}")
        return None

def save_time_series(conn, video):
    """
    Legt einen Eintrag in der Tabelle 'media_time_series' an,
    um einen Zeitstempel der aktuellen Stats zu speichern.
    """
    cur = conn.cursor()
    try:
        cur.execute(
            """
            INSERT INTO media_time_series (
                url, view_count, like_count, repost_count, comment_count, recorded_at
            )
            VALUES (%s, %s, %s, %s, %s, %s)
            """,
            (
                video.get("url"),
                video.get("view_count"),
                video.get("like_count"),
                video.get("repost_count"),
                video.get("comment_count"),
                datetime.now()
            )
        )
    except psycopg2.Error as e:
        logging.error(f"Fehler bei Insert in media_time_series: {e}")
    finally:
        cur.close()

def save_video_metadata(conn, video):
    """
    Schreibt Metadaten in 'media_metadata', falls noch nicht vorhanden.
    Legt anschließend neuen Zeitreihen-Eintrag an.
    Nutzt INSERT ... ON CONFLICT DO NOTHING, um Doppel-Primary-Keys zu vermeiden.
    """
    cur = conn.cursor()

    # Metadaten in media_metadata einfügen, vorhandene Einträge nicht updaten
    try:
        cur.execute(
            """
            INSERT INTO media_metadata (
                id,
                url,
                title,
                description,
                duration,
                view_count,
                like_count,
                repost_count,
                comment_count,
                uploader,
                uploader_id,
                channel,
                channel_id,
                channel_url,
                track,
                album,
                artists,
                timestamp,
                extractor
            )
            VALUES (
                %s, %s, %s, %s, %s, %s, %s, %s, %s,
                %s, %s, %s, %s, %s, %s, %s, %s,
                %s, %s
            )
            ON CONFLICT (id) DO NOTHING
            """,
            (
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
                video.get("extractor"),
            )
        )
    except psycopg2.Error as e:
        logging.error(f"Fehler bei Insert in media_metadata: {e}")
    finally:
        cur.close()

    # Zeitreihen-Eintrag hinzufügen
    save_time_series(conn, video)

def process_playlist_metadata(conn, playlist_metadata):
    """
    Iteriert über alle 'entries' im JSON und führt save_video_metadata aus.
    """
    if not playlist_metadata or "entries" not in playlist_metadata:
        logging.debug("Keine 'entries' in den Metadaten gefunden.")
        return

    for video in playlist_metadata["entries"]:
        save_video_metadata(conn, video)

def process_links_with_locking():
    """
    Wendet row-level locking an, um bei parallelen Prozessen
    jede Zeile nur einmal zu verarbeiten.
    FOR UPDATE SKIP LOCKED springt Einträge,
    die bereits durch eine andere Transaktion gelockt sind, einfach über.
    
    Wichtig: Es erfolgt nur ein INSERT, kein Update auf existing rows.
    """
    conn = get_connection()
    cur = conn.cursor()

    try:
        cur.execute(
            """
            SELECT id, url
            FROM links
            ORDER BY id
            FOR UPDATE SKIP LOCKED
            """
        )
        rows = cur.fetchall()
        logging.info(f"{len(rows)} Zeilen gelockt. Verarbeitung beginnt.")

        for (link_id, link_url) in rows:
            logging.info(f"Link-ID: {link_id}, URL: {link_url}")
            metadata_json = extract_metadata(link_url)

            if metadata_json:
                process_playlist_metadata(conn, metadata_json)
                # Beispiel: An dieser Stelle könnten weitere Insert-Operationen erfolgen.
                # Keine Aktualisierung des processed-Flags, da nur INSERT-Rechte erwünscht.

                conn.commit()  # Nach Verarbeitung committen
                logging.info(f"Link {link_id} verarbeitet und Daten gespeichert.")
            else:
                logging.warning(f"Keine Metadaten oder Fehler für {link_url}")

    except psycopg2.Error as db_error:
        logging.error(f"Datenbank-Fehler: {db_error}")
        conn.rollback()
    finally:
        cur.close()
        conn.close()
        logging.info("Locked-Durchlauf beendet.")

def main():
    """
    Hauptfunktion. Führt den Datenbankzugriff und die Metadaten-Verarbeitung aus.
    """
    process_links_with_locking()

if __name__ == "__main__":
    main()