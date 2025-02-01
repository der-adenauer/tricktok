import os
import json
import time
import sqlite3
import logging
import requests
import traceback
from datetime import datetime, timedelta

# Logging konfigurieren
logging.basicConfig(
    filename='peertube_upload.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

# --- PeerTube-Konfiguration ---
PEERTUBE_URL = "https://archive.afd-verbot.de"
PEERTUBE_HOST = f"{PEERTUBE_URL}/api/v1"
USERNAME = "name"
PASSWORD = "password"
TOKEN_FILE = "peertube_token.json"

PRIVACY = 1
CATEGORY = 1
LICENCE = 1
CHANNEL_ID = 3

# --- Datenbank-Konfiguration ---
DB_PATH = "archiv/filtered_tiktok_media.db"
TABLE_NAME = "media_info"

# Basisverzeichnis für die Video-Dateien
BASE_VIDEO_DIR = "/mnt/HC_Volume_101955489/tricktok-archiv"

# Benötigte Spalten für PeerTube-Upload
REQUIRED_COLUMNS = [
    ("video_id", "INTEGER"),
    ("video_uuid", "TEXT"),
    ("embedded_link", "TEXT")
]

# --- Token-Management-Funktionen ---

def get_client_credentials():
    """
    OAuth-Client-Daten von der PeerTube-Instanz abrufen.
    """
    try:
        url = f"{PEERTUBE_URL}/api/v1/oauth-clients/local"
        response = requests.get(url)
        if response.status_code == 200:
            data = response.json()
            logging.info("Client-Credentials erfolgreich abgerufen.")
            return data['client_id'], data['client_secret']
        else:
            msg = f"Fehler beim Abrufen der OAuth-Daten: {response.status_code} - {response.text}"
            logging.error(msg)
            raise Exception(msg)
    except Exception as e:
        logging.error(f"Ausnahme beim Abrufen der OAuth-Daten: {e}")
        traceback.print_exc()
        raise

def get_user_token(client_id, client_secret):
    """
    Benutzerzugangstoken über client_id, client_secret, Benutzername und Passwort abrufen.
    """
    url = f"{PEERTUBE_URL}/api/v1/users/token"
    payload = {
        "client_id": client_id,
        "client_secret": client_secret,
        "grant_type": "password",
        "response_type": "code",
        "username": USERNAME,
        "password": PASSWORD
    }
    headers = {
        "Content-Type": "application/x-www-form-urlencoded"
    }
    try:
        response = requests.post(url, data=payload, headers=headers)
        if response.status_code == 200:
            logging.info("Benutzerzugangstoken erfolgreich abgerufen.")
            return response.json()
        else:
            msg = f"Fehler beim Abrufen des Tokens: {response.status_code} - {response.text}"
            logging.error(msg)
            raise Exception(msg)
    except Exception as e:
        logging.error(f"Ausnahme beim Abrufen des Tokens: {e}")
        traceback.print_exc()
        raise

def save_token(token_data):
    """
    Token und Ablaufdatum in lokaler JSON-Datei speichern.
    """
    try:
        token_data['expires_at'] = (
            datetime.now() + timedelta(seconds=token_data['expires_in'])
        ).isoformat()
        with open(TOKEN_FILE, 'w', encoding='utf-8') as f:
            json.dump(token_data, f)
        logging.info("Token gespeichert.")
    except Exception as e:
        logging.error(f"Fehler beim Speichern des Tokens: {e}")
        traceback.print_exc()

def load_token():
    """
    Token aus lokaler JSON-Datei laden.
    """
    if not os.path.exists(TOKEN_FILE):
        logging.info("Token-Datei fehlt, kann nicht geladen werden.")
        return None
    try:
        with open(TOKEN_FILE, 'r', encoding='utf-8') as f:
            token_data = json.load(f)
        logging.info("Token geladen.")
        return token_data
    except Exception as e:
        logging.error(f"Fehler beim Laden des Tokens: {e}")
        traceback.print_exc()
        return None

def is_token_valid(token_data):
    """
    Gültigkeit des gespeicherten Tokens prüfen.
    """
    if not token_data:
        return False
    try:
        expires_at = datetime.fromisoformat(token_data['expires_at'])
        if datetime.now() < expires_at:
            logging.info("Gespeicherter Token ist noch gültig.")
            return True
        logging.info("Gespeicherter Token ist abgelaufen.")
        return False
    except Exception as e:
        logging.error(f"Fehler bei der Token-Gültigkeitsprüfung: {e}")
        traceback.print_exc()
        return False

def get_valid_token():
    """
    Stellt sicher, dass ein gültiger Token vorliegt. Liefert Access-Token als String.
    """
    token_data = load_token()
    if not is_token_valid(token_data):
        logging.info("Neuen Token generieren (kein gültiger gespeichert).")
        try:
            client_id, client_secret = get_client_credentials()
            token_data = get_user_token(client_id, client_secret)
            save_token(token_data)
        except Exception as e:
            logging.error(f"Fehler beim Generieren eines neuen Tokens: {e}")
            traceback.print_exc()
            raise
    return token_data['access_token']

# --- Upload-Funktion ---

def upload_video_to_peertube(video_path, title, description=""):
    """
    Upload zu PeerTube. Rückgabe von (video_id, video_uuid, embedded_link).
    """
    access_token = get_valid_token()

    upload_url = f"{PEERTUBE_HOST}/videos/upload"
    headers = {"Authorization": f"Bearer {access_token}"}
    files = {
        "videofile": (os.path.basename(video_path), open(video_path, 'rb'), "video/mp4")
    }
    data = {
        "name": title[:100],
        "channelId": CHANNEL_ID,
        "privacy": PRIVACY,
        "category": CATEGORY,
        "licence": LICENCE,
        "description": description if description else "Keine Beschreibung angegeben"
    }

    logging.info(f"Starte Video-Upload: {video_path}")
    try:
        resp = requests.post(upload_url, headers=headers, files=files, data=data)
        if resp.status_code == 200:
            result_json = resp.json()
            vid_id = result_json['video']['id']
            vid_uuid = result_json['video']['uuid']
            embed_link = f"{PEERTUBE_URL}/videos/embed/{vid_uuid}"
            logging.info(f"Upload erfolgreich. Video-ID: {vid_id}, UUID: {vid_uuid}")
            return vid_id, vid_uuid, embed_link
        else:
            msg = f"Fehler beim Upload. Status: {resp.status_code}, Antwort: {resp.text}"
            logging.error(msg)
            raise Exception(msg)
    except Exception as e:
        logging.error(f"Allgemeiner Fehler beim Upload zu PeerTube: {e}")
        traceback.print_exc()
        raise
    finally:
        files['videofile'][1].close()  # Datei schließen

# --- Hauptprogramm ---

def main():
    start_time = time.time()
    logging.info("Starte PeerTube-Upload-Skript.")

    conn = sqlite3.connect(DB_PATH)
    cursor = conn.cursor()

    # Fehlende Spalten anlegen
    for col, col_type in REQUIRED_COLUMNS:
        try:
            cursor.execute(f"PRAGMA table_info({TABLE_NAME});")
            existing_cols = [info[1] for info in cursor.fetchall()]
            if col not in existing_cols:
                cursor.execute(f"ALTER TABLE {TABLE_NAME} ADD COLUMN {col} {col_type}")
                conn.commit()
                logging.info(f"Spalte '{col}' hinzugefügt.")
        except Exception as e:
            logging.error(f"Fehler beim Hinzufügen der Spalte '{col}': {e}")
            traceback.print_exc()

    # Zu verarbeitende Datensätze suchen
    query = f"""
        SELECT id, video_path, title, description
        FROM {TABLE_NAME}
        WHERE video_id IS NULL
           OR video_uuid IS NULL
           OR embedded_link IS NULL
           OR video_id = ''
           OR video_uuid = ''
           OR embedded_link = ''
    """
    cursor.execute(query)
    rows = cursor.fetchall()
    logging.info(f"Zu verarbeitende Einträge: {len(rows)}")

    for row in rows:
        row_id, db_video_path, vid_title, vid_desc = row

        # Überprüfen, ob video_path vorliegt und ein String ist
        if not db_video_path or not isinstance(db_video_path, str):
            logging.warning(f"ID {row_id}: Ungültiger video_path: {db_video_path}")
            continue

        # Vollständiger Pfad
        full_video_path = os.path.join(BASE_VIDEO_DIR, db_video_path)

        # Existenz der Datei prüfen
        if not os.path.exists(full_video_path):
            logging.warning(f"ID {row_id}: Datei nicht gefunden: {full_video_path}")
            continue

        # Titel/Beschreibung als Fallback auf Dateinamen
        vid_title = vid_title if vid_title else os.path.basename(full_video_path)
        vid_desc = vid_desc if vid_desc else ""

        logging.info(f"Starte Upload für ID {row_id}, Datei: {full_video_path}")
        try:
            video_id, video_uuid, embedded_link = upload_video_to_peertube(
                video_path=full_video_path,
                title=vid_title,
                description=vid_desc
            )
            update_query = f"""
                UPDATE {TABLE_NAME}
                SET video_id = ?,
                    video_uuid = ?,
                    embedded_link = ?
                WHERE id = ?
            """
            cursor.execute(update_query, (video_id, video_uuid, embedded_link, row_id))
            conn.commit()
            logging.info(f"Upload-Infos für ID {row_id} gespeichert.")

            # Kurz warten, bevor nächster Upload beginnt
            time.sleep(2)

        except Exception as e:
            logging.error(f"Fehler bei ID {row_id}: {e}")
            traceback.print_exc()

    cursor.close()
    conn.close()
    logging.info("Verarbeitung abgeschlossen. Datenbankverbindung geschlossen.")

    end_time = time.time()
    elapsed_seconds = end_time - start_time
    logging.info(f"PeerTube-Upload-Skript beendet. Laufzeit: {elapsed_seconds:.2f} Sekunden.")

if __name__ == "__main__":
    main()
