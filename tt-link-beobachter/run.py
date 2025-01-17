import os
import sqlite3
import subprocess
import json
import logging

# Logging konfigurieren
logging.basicConfig(
    filename='metadata_extraction.log',
    level=logging.DEBUG,
    format='%(asctime)s - %(levelname)s - %(message)s'
)
logging.info("Skript gestartet")

new_entries_count = 0  # Zähler für neue Einträge

# SQLite-Datenbank erstellen oder öffnen
def init_db(db_name="media_metadata.db"):
    logging.debug(f"Initialisiere Datenbank: {db_name}")
    conn = sqlite3.connect(db_name)
    cursor = conn.cursor()
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
    conn.commit()
    logging.debug("Datenbank initialisiert")
    return conn

# Metadaten extrahieren mit yt-dlp
def extract_metadata(url):
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

# Einzelne Video-Metadaten in SQLite speichern
def save_video_metadata(conn, video):
    global new_entries_count
    cursor = conn.cursor()
    try:
        # Überprüfen, ob bereits ein Eintrag mit derselben URL existiert
        cursor.execute("SELECT 1 FROM media_metadata WHERE url = ?", (video.get("url"),))
        if cursor.fetchone():
            logging.debug(f"Video mit URL {video.get('url')} existiert bereits. Überspringe Eintrag.")
            return

        cursor.execute('''
            INSERT OR REPLACE INTO media_metadata (
                id, url, title, description, duration, view_count,
                like_count, repost_count, comment_count, uploader,
                uploader_id, channel, channel_id, channel_url, track,
                album, artists, timestamp, extractor
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
        new_entries_count += 1
        logging.debug(f"Metadaten für Video ID={video.get('id')} gespeichert")
    except sqlite3.Error as e:
        logging.error(f"SQLite-Fehler bei Video ID={video.get('id')}: {e}")

# Playlist verarbeiten und Metadaten speichern
def process_playlist_metadata(conn, playlist_metadata):
    if not playlist_metadata or "entries" not in playlist_metadata:
        logging.debug("Keine Videos in der Playlist gefunden")
        return

    for video in playlist_metadata["entries"]:
        save_video_metadata(conn, video)

# Links aus Datei lesen und verarbeiten
def process_links(file_name="links.txt", db_name="media_metadata.db"):
    logging.debug(f"Beginne Verarbeitung von Links aus Datei: {file_name}")
    conn = init_db(db_name)
    if not os.path.exists(file_name):
        logging.error(f"Datei {file_name} nicht gefunden")
        return

    with open(file_name, "r") as file:
        links = [line.strip() for line in file if line.strip()]

    logging.debug(f"Gefundene Links: {links}")

    for url in links:
        logging.info(f"Verarbeite URL: {url}")
        playlist_metadata = extract_metadata(url)
        if playlist_metadata:
            process_playlist_metadata(conn, playlist_metadata)
        else:
            logging.warning(f"Keine Metadaten gefunden für URL: {url}")

    conn.close()
    logging.debug("Verarbeitung abgeschlossen")
    print(f"{new_entries_count} neue Einträge hinzugefügt.")

if __name__ == "__main__":
    process_links()
