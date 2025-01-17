# app.py
import re
import time
import sqlite3
from flask import Flask, request, g, render_template, redirect, url_for, session

app = Flask(__name__)
app.secret_key = "irgend_ein_schlüssel"

# Datenbankverbindung herstellen
def get_db():
    db = getattr(g, "_database", None)
    if db is None:
        db = g._database = sqlite3.connect("datenbank.db")
        db.execute(
            "CREATE TABLE IF NOT EXISTS links (id INTEGER PRIMARY KEY AUTOINCREMENT, kanal TEXT, zeitstempel REAL, user_agent TEXT)"
        )
    return db

# Verbindung schließen
@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, "_database", None)
    if db is not None:
        db.close()

# Funktion zur TikTok-Link-Verarbeitung
def extract_channel(link):
    """
    Extrahiert den Kanalnamen aus einem TikTok-Link.
    """
    pattern = r"(?:https?:\/\/)?(?:www\.)?tiktok\.com\/@([^\/]+)"
    match = re.search(pattern, link)
    if match:
        return match.group(1)
    return None

# Startseite mit Eingabeformular und Auflistung aller gespeicherten Links
@app.route("/", methods=["GET", "POST"])
def index():
    db = get_db()
    links = db.execute("SELECT kanal, zeitstempel, user_agent FROM links").fetchall()

    if request.method == "POST":
        letzte_zeit = session.get("last_submit_time", 0)
        aktuelle_zeit = time.time()

        # 10 Sekunden Sperre prüfen
        if aktuelle_zeit - letzte_zeit < 10:
            return render_template("index.html", links=links, fehlermeldung="Nur alle 10 Sekunden möglich")

        eingabe_link = request.form.get("eingabe_link", "").strip()

        # TikTok-Link extrahieren
        kanal_name = extract_channel(eingabe_link)
        if not kanal_name:
            return render_template("index.html", links=links, fehlermeldung="Kein gültiger TikTok-Link")

        # Kürzen des Links
        gekuerzter_link = f"https://www.tiktok.com/@{kanal_name}"

        # In Datenbank speichern
        zeit = time.time()
        user_agent = request.headers.get("User-Agent", "Unbekannt")
        cursor = db.cursor()
        cursor.execute(
            "INSERT INTO links (kanal, zeitstempel, user_agent) VALUES (?, ?, ?)",
            (kanal_name, zeit, user_agent),
        )
        db.commit()

        # 10-Sekunden-Sperre aktualisieren
        session["last_submit_time"] = aktuelle_zeit

        return redirect(url_for("index"))

    return render_template("index.html", links=links)

if __name__ == "__main__":
    app.run(debug=True)
