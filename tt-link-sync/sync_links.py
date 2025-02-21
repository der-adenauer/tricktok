import os
import psycopg2
import logging
from dotenv import load_dotenv

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

load_dotenv()

DB_HOST = os.getenv("DB_HOST")
DB_PORT = os.getenv("DB_PORT")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASS = os.getenv("DB_PASS")

def get_connection():
    """
    Verbindung zur PostgreSQL-Datenbank herstellen.
    Verbindungsdaten werden aus Umgebungsvariablen gelesen.
    """
    return psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASS
    )

def init_db():
    """
    Tabelle 'links' anlegen, falls nicht vorhanden.
    Spalten:
      - id (SERIAL PRIMARY KEY): Automatisch hochgezählter Primärschlüssel
      - url (TEXT NOT NULL): TikTok-Link
      - inserted_at (TIMESTAMP WITH TIME ZONE DEFAULT now()): Zeitstempel beim Insert
      - processed (BOOLEAN DEFAULT false): Flag zum Kennzeichnen, ob Eintrag verarbeitet wurde
    """
    logging.info("Erstellung der Tabelle 'links' (falls nicht vorhanden).")
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
        # Optionaler UNIQUE Constraint für Spalte url:
        # cur.execute("ALTER TABLE links ADD CONSTRAINT unique_url UNIQUE (url);")
        conn.commit()
    except psycopg2.Error as e:
        logging.error(f"Fehler bei CREATE TABLE: {e}")
        conn.rollback()
    finally:
        cur.close()
        conn.close()

def insert_links_from_file(links_file="links.txt"):
    """
    Einlesen von Zeilen aus einer Datei (links_file) und Insert in Tabelle 'links'.
    Einfügen erfolgt nur, wenn ein Eintrag mit dieser URL noch nicht existiert.
    """
    if not os.path.exists(links_file):
        logging.error(f"Datei '{links_file}' nicht gefunden!")
        return

    with open(links_file, "r", encoding="utf-8") as f:
        raw_lines = [line.strip() for line in f]

    urls = [l for l in raw_lines if l]

    if not urls:
        logging.info(f"Keine URLs in '{links_file}' gefunden.")
        return

    logging.info(f"Anzahl neuer URLs in {links_file}: {len(urls)}")

    conn = get_connection()
    cur = conn.cursor()
    inserted_count = 0
    try:
        for url in urls:
            cur.execute("""
            INSERT INTO links (url)
            SELECT %s
            WHERE NOT EXISTS (SELECT 1 FROM links WHERE url = %s);
            """, (url, url))
            if cur.rowcount > 0:
                inserted_count += 1

        conn.commit()
        logging.info(f"Fertig. {inserted_count} neue Einträge eingefügt.")
    except psycopg2.Error as e:
        logging.error(f"Fehler beim Einfügen: {e}")
        conn.rollback()
    finally:
        cur.close()
        conn.close()

def main():
    init_db()
    insert_links_from_file("links.txt")

if __name__ == "__main__":
    main()
