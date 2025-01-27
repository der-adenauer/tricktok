import os
import sqlite3
import subprocess
import json
import logging
from datetime import datetime

# Logging konfigurieren (im Append-Modus, damit kontinuierlich geloggt wird)
logging.basicConfig(
    filename='tiktok_metadata_extraction.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s',
    filemode='a'
)
logging.info("Skript gestartet")

new_entries_count = 0
stats_since_last_link = {"new": 0, "updates": 0}

# Dictionary für Kanal-Zusammenfassungen
# Struktur: channel_summaries[channel_name] = {"channel_url": str, "new": int, "updates": int}
channel_summaries = {}

def init_db(db_name="tiktok_media_metadata.db"):
    logging.debug(f"Initialisiere Datenbank: {db_name}")
    conn = sqlite3.connect(db_name)
    cursor = conn.cursor()

    # Erste Tabelle für aktuelle Metadaten
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS media_metadata (
            id TEXT PRIMARY KEY,
            url TEXT,
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
            timestamp INTEGER,
            extractor TEXT
        )
    ''')

    # Zweite Tabelle für historische Datensätze (Zeitreihen)
    cursor.execute('''
        CREATE TABLE IF NOT EXISTS media_time_series (
            series_id INTEGER PRIMARY KEY AUTOINCREMENT,
            url TEXT,
            view_count INTEGER,
            like_count INTEGER,
            repost_count INTEGER,
            comment_count INTEGER,
            recorded_at DATETIME
        )
    ''')

    conn.commit()
    logging.debug("Datenbank initialisiert")
    return conn

def extract_metadata(url):
    """
    Extrahiert Metadaten mit Hilfe von yt-dlp im JSON-Format.
    """
    logging.debug(f"Extrahiere Metadaten für URL: {url}")
    try:
        result = subprocess.run(
            ["yt-dlp", "--flat-playlist", "--dump-single-json", url],
            capture_output=True,
            text=True
        )
        if result.returncode == 0:
            logging.debug(f"Metadaten erfolgreich extrahiert für URL: {url}")
            return json.loads(result.stdout)
        else:
            logging.error(f"Fehler beim Abrufen von {url}: {result.stderr}")
            return None
    except Exception as e:
        logging.error(f"Fehler beim Abrufen von {url}: {e}")
        return None

def save_time_series(conn, video):
    """
    Speichert Zeitreihen-Datensatz in media_time_series.
    """
    cursor = conn.cursor()
    now_str = datetime.now().isoformat()
    cursor.execute('''
        INSERT INTO media_time_series (
            url, view_count, like_count, repost_count, comment_count, recorded_at
        ) VALUES (?, ?, ?, ?, ?, ?)
    ''', (
        video.get("url"),
        video.get("view_count"),
        video.get("like_count"),
        video.get("repost_count"),
        video.get("comment_count"),
        now_str
    ))
    conn.commit()
    logging.debug(f"Neuer Eintrag in media_time_series für URL {video.get('url')} gespeichert")

def update_existing_video(conn, existing_data, new_data):
    """
    Aktualisiert einen vorhandenen Eintrag in media_metadata
    und speichert alte Werte für das Logging.
    """
    cursor = conn.cursor()

    old_view, old_like, old_repost, old_comment = existing_data

    new_view = new_data.get("view_count")
    new_like = new_data.get("like_count")
    new_repost = new_data.get("repost_count")
    new_comment = new_data.get("comment_count")

    diff_msg = (
        f"URL {new_data.get('url')} Aktualisierung der Stats: "
        f"Views alt={old_view}, neu={new_view}; "
        f"Likes alt={old_like}, neu={new_like}; "
        f"Reposts alt={old_repost}, neu={new_repost}; "
        f"Comments alt={old_comment}, neu={new_comment}"
    )
    logging.info(diff_msg)

    cursor.execute('''
        UPDATE media_metadata
        SET title = ?,
            description = ?,
            duration = ?,
            view_count = ?,
            like_count = ?,
            repost_count = ?,
            comment_count = ?,
            uploader = ?,
            uploader_id = ?,
            channel = ?,
            channel_id = ?,
            channel_url = ?,
            track = ?,
            album = ?,
            artists = ?,
            timestamp = ?,
            extractor = ?
        WHERE url = ?
    ''', (
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

def save_video_metadata(conn, video):
    """
    Schreibt oder aktualisiert einen Datensatz in media_metadata.
    Führt außerdem einen Zeitreihen-Eintrag in media_time_series durch.
    """
    global new_entries_count, stats_since_last_link
    cursor = conn.cursor()

    # Kanal und Kanal-URL ermitteln (falls nicht vorhanden: "Unknown")
    channel_name = video.get("channel") or "Unknown"
    channel_url = video.get("channel_url") or "Unknown"

    # Falls channel_name in channel_summaries noch nicht existiert, initialisieren
    if channel_name not in channel_summaries:
        channel_summaries[channel_name] = {"channel_url": channel_url, "new": 0, "updates": 0}

    # Prüfen, ob dieses Video (URL) schon existiert
    cursor.execute("""
        SELECT view_count, like_count, repost_count, comment_count
        FROM media_metadata
        WHERE url = ?
    """, (video.get("url"),))
    existing = cursor.fetchone()

    if existing:
        update_existing_video(conn, existing, video)
        save_time_series(conn, video)
        channel_summaries[channel_name]["updates"] += 1
        stats_since_last_link["updates"] += 1
        return

    try:
        # Neuer Datensatz
        cursor.execute('''
            INSERT OR REPLACE INTO media_metadata (
                id, url, title, description, duration,
                view_count, like_count, repost_count, comment_count,
                uploader, uploader_id, channel, channel_id,
                channel_url, track, album, artists,
                timestamp, extractor
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ''', (
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
            channel_name,
            video.get("channel_id"),
            channel_url,
            video.get("track"),
            video.get("album"),
            ", ".join(video.get("artists", [])),
            video.get("timestamp"),
            video.get("extractor")
        ))
        conn.commit()

        new_entries_count += 1
        logging.info(f"Neuer Datensatz für Video ID={video.get('id')} (URL={video.get('url')}) gespeichert")
        save_time_series(conn, video)
        channel_summaries[channel_name]["new"] += 1
        stats_since_last_link["new"] += 1

    except sqlite3.Error as e:
        logging.error(f"SQLite-Fehler bei Video ID={video.get('id')}: {e}")

def process_playlist_metadata(conn, playlist_metadata):
    if not playlist_metadata or "entries" not in playlist_metadata:
        logging.debug("Keine Videos in Playlist gefunden")
        return
    for video in playlist_metadata["entries"]:
        save_video_metadata(conn, video)

def process_links(file_name="links.txt", db_name="tiktok_media_metadata.db"):
    """
    Hauptfunktion zum Einlesen der Linkliste, Metadaten-Extrahieren und Speichern.
    """
    global new_entries_count, stats_since_last_link

    logging.debug(f"Beginne Verarbeitung von Links aus Datei: {file_name}")
    conn = init_db(db_name)
    if not os.path.exists(file_name):
        logging.error(f"Datei {file_name} nicht gefunden")
        return

    with open(file_name, "r") as file:
        links = [line.strip() for line in file if line.strip()]

    logging.debug(f"Gefundene Links: {links}")

    for idx, url in enumerate(links, start=1):
        logging.info(f"Verarbeitung von URL {idx}/{len(links)}: {url}")
        playlist_metadata = extract_metadata(url)
        if playlist_metadata:
            process_playlist_metadata(conn, playlist_metadata)
            logging.info(f"Zusammenfassung für URL {url}: Neue Videos: {stats_since_last_link['new']}, Updates: {stats_since_last_link['updates']}")
            stats_since_last_link = {"new": 0, "updates": 0}
        else:
            logging.warning(f"Keine Metadaten für URL: {url}")

    logging.info("----- Zusammenfassung pro Kanal -----")
    for chan, stats in channel_summaries.items():
        logging.info(f"Kanal: {chan} | Kanal-URL: {stats['channel_url']} | Neue Einträge: {stats['new']} | Updates: {stats['updates']}")

    logging.info("----- Gesamtzusammenfassung -----")
    total_new = sum(stats['new'] for stats in channel_summaries.values())
    total_updates = sum(stats['updates'] for stats in channel_summaries.values())
    logging.info(f"Gesamtneue Einträge: {total_new}")
    logging.info(f"Gesamtupdates: {total_updates}")
    logging.info("Verarbeitung abgeschlossen")

    print(f"{new_entries_count} neue Einträge hinzugefügt.")
    conn.close()

if __name__ == "__main__":
    process_links()
