import re
import time
import sqlite3
import logging
from datetime import datetime
from flask import Flask, request, g, render_template, redirect, url_for, Response

logging.basicConfig(
    filename="app.log",
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s"
)

app = Flask(__name__)
app.secret_key = "irgeJGD234FG23FGD&2%34$§%§$n23d_ein_s544235223525sel"

def get_db():
    """
    Stellt die Verbindung zur 'datenbank.db' her und legt bei Bedarf die Tabellen an.
    Stellt sicher, dass 'last_export' in ip_cooldowns existiert.
    """
    db = getattr(g, "_database", None)
    if db is None:
        db = g._database = sqlite3.connect("datenbank.db")
        # Haupttabelle für Links
        db.execute("""
            CREATE TABLE IF NOT EXISTS links (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kanal TEXT,
                zeitstempel TEXT,
                user_agent TEXT,
                ip_address TEXT
            )
        """)
        # IP-Cooldown-Tabelle
        db.execute("""
            CREATE TABLE IF NOT EXISTS ip_cooldowns (
                ip TEXT PRIMARY KEY,
                last_submit REAL,
                last_export REAL
            )
        """)
        # Prüfen, ob 'last_export' existiert, sonst via ALTER TABLE hinzufügen
        try:
            db.execute("SELECT last_export FROM ip_cooldowns LIMIT 1")
        except sqlite3.OperationalError:
            db.execute("ALTER TABLE ip_cooldowns ADD COLUMN last_export REAL")
    return db

@app.teardown_appcontext
def close_connection(exception):
    """
    Schließt die DB-Verbindung nach jedem Request.
    """
    db = getattr(g, "_database", None)
    if db is not None:
        db.close()

def extract_channel(link):
    """
    Extrahiert den TikTok-Kanal (@username) aus einem übergebenen Link-String.
    """
    pattern = r"(?:https?:\/\/)?(?:www\.)?tiktok\.com\/@([^\/]+)"
    match = re.search(pattern, link.strip())
    if match:
        return match.group(1)
    return None

@app.route("/", methods=["GET", "POST"])
def index():
    """
    Zeigt die TikTok-Links (paginiert) und erlaubt das Hinzufügen neuer Links.
    -> 10s-Cooldown pro IP für neue Einträge (last_submit).
    """
    db = get_db()
    page = int(request.args.get("page", 1))
    per_page = 5
    offset = (page - 1) * per_page

    total_links = db.execute("SELECT COUNT(*) FROM links").fetchone()[0]
    rows = db.execute("""
        SELECT kanal, zeitstempel
        FROM links
        ORDER BY id DESC
        LIMIT ? OFFSET ?
    """, (per_page, offset)).fetchall()

    fehlermeldung = None

    if request.method == "POST":
        # IP ermitteln
        ip_address = request.headers.get("X-Forwarded-For", request.remote_addr) or "Unbekannt"
        if "," in ip_address:
            ip_address = ip_address.split(",")[0].strip()

        aktuelle_zeit = time.time()
        cursor = db.cursor()

        # Letzten POST prüfen => 10s
        row = cursor.execute(
            "SELECT last_submit FROM ip_cooldowns WHERE ip = ?",
            (ip_address,)
        ).fetchone()

        last_submit = row[0] if row else 0
        if (aktuelle_zeit - (last_submit or 0)) < 10:
            fehlermeldung = "Nur alle 10 Sekunden möglich"
            logging.info("Abgewiesen: IP %s Link-Post zu schnell nacheinander.", ip_address)
            return render_template(
                "index.html",
                links=rows,
                fehlermeldung=fehlermeldung,
                total_links=total_links,
                page=page,
                per_page=per_page
            )

        # Link verarbeiten
        eingabe_text = request.form.get("eingabe_link", "").strip()
        kanal_name = extract_channel(eingabe_text)
        if not kanal_name:
            fehlermeldung = "Keine gültige TikTok-URL gefunden"
            logging.info("Ungültiger Link: %s", eingabe_text)
            return render_template(
                "index.html",
                links=rows,
                fehlermeldung=fehlermeldung,
                total_links=total_links,
                page=page,
                per_page=per_page
            )

        # Duplikat-Check
        cursor.execute("SELECT zeitstempel FROM links WHERE kanal = ? LIMIT 1", (kanal_name,))
        duplikat = cursor.fetchone()
        if duplikat:
            vorhandenes_datum = duplikat[0]
            fehlermeldung = f"Kanal bereits vorhanden (zuletzt am {vorhandenes_datum})"
            logging.info("Kanal bereits vorhanden: %s (IP: %s)", kanal_name, ip_address)

            # last_submit aktualisieren (last_export bleibt unverändert)
            cursor.execute("""
                INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
                VALUES (
                    ?,
                    ?,
                    COALESCE((SELECT last_export FROM ip_cooldowns WHERE ip = ?), NULL)
                )
            """, (ip_address, aktuelle_zeit, ip_address))
            db.commit()

            return render_template(
                "index.html",
                links=rows,
                fehlermeldung=fehlermeldung,
                total_links=total_links,
                page=page,
                per_page=per_page
            )
        else:
            # Neuen Link einfügen
            zeit = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            user_agent = request.headers.get("User-Agent", "Unbekannt")

            cursor.execute("""
                INSERT INTO links (kanal, zeitstempel, user_agent, ip_address)
                VALUES (?, ?, ?, ?)
            """, (kanal_name, zeit, user_agent, ip_address))
            db.commit()
            logging.info("Neuer Kanal gespeichert: %s (IP: %s)", kanal_name, ip_address)

            # last_submit aktualisieren
            cursor.execute("""
                INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
                VALUES (
                    ?,
                    ?,
                    COALESCE((SELECT last_export FROM ip_cooldowns WHERE ip = ?), NULL)
                )
            """, (ip_address, aktuelle_zeit, ip_address))
            db.commit()

        return redirect(url_for("index", show_eingabe=1, success=1))

    # GET => Liste
    return render_template(
        "index.html",
        links=rows,
        fehlermeldung=fehlermeldung,
        total_links=total_links,
        page=page,
        per_page=per_page
    )

@app.route("/export_csv", methods=["GET"])
def export_csv():
    """
    CSV-Export (id, kanal, zeitstempel) mit 30s-Cooldown pro IP.
    Falls im Query-String parameter wie page=... oder show_datenbank=...
    vorkommen, leiten wir auf '/' um, damit die Navigation intakt bleibt.
    """
    # Falls die URL z.B. /export_csv?page=2 => umleiten auf index
    forbidden_params = {"page", "show_datenbank"}
    if any(param in request.args for param in forbidden_params):
        return redirect(url_for("index", **request.args))

    db = get_db()
    cursor = db.cursor()

    # IP
    ip_address = request.headers.get("X-Forwarded-For", request.remote_addr) or "Unbekannt"
    if "," in ip_address:
        ip_address = ip_address.split(",")[0].strip()

    aktuelle_zeit = time.time()

    # 30s-Cooldown => last_export
    row = cursor.execute(
        "SELECT last_export FROM ip_cooldowns WHERE ip = ?",
        (ip_address,)
    ).fetchone()
    last_export = row[0] if row else 0

    if (aktuelle_zeit - (last_export or 0)) < 30:
        fehlermeldung = "Export nur alle 30 Sekunden möglich"
        logging.info("Export abgewiesen: IP %s hatte <30s Abstand.", ip_address)

        # Nur Fehlermeldung => wir rendern index.html
        total_links = db.execute("SELECT COUNT(*) FROM links").fetchone()[0]
        rows = db.execute("""
            SELECT kanal, zeitstempel
            FROM links
            ORDER BY id DESC
            LIMIT 5
        """).fetchall()

        return render_template(
            "index.html",
            links=rows,
            fehlermeldung=fehlermeldung,
            total_links=total_links,
            page=1,
            per_page=5
        )

    # Falls ok => generiere CSV
    rows = cursor.execute("""
        SELECT id, kanal, zeitstempel
        FROM links
        ORDER BY id
    """).fetchall()

    csv_data = "id,kanal,zeitstempel\n"
    for (id_val, kanal_val, zeit_val) in rows:
        csv_data += f"{id_val},{kanal_val},{zeit_val}\n"

    # last_export aktualisieren
    cursor.execute("""
        INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
        VALUES (
            ?,
            COALESCE((SELECT last_submit FROM ip_cooldowns WHERE ip = ?), NULL),
            ?
        )
    """, (ip_address, ip_address, aktuelle_zeit))
    db.commit()

    return Response(
        csv_data,
        mimetype="text/csv",
        headers={"Content-disposition": "attachment; filename=links_export.csv"}
    )

@app.route("/info")
def info():
    """
    Info-Seite
    """
    return render_template("info.html")

@app.route("/contact")
def contact():
    """
    Kontakt-Seite
    """
    return render_template("contact.html")
    
    
@app.route("/channel_extractor")
def channel_extractor():
    """
    Gibt den Inhalt von channel-link-extractor.html zurück.
    Hier kann ein HTML-/JS-Inhalt liegen.
    """
    return render_template("channel-link-extractor.html")


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
