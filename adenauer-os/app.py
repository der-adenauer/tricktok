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
app.secret_key = "irgendein_schluessel"

def get_db():
    db = getattr(g, "_database", None)
    if db is None:
        # 1) Connect
        db = g._database = sqlite3.connect("datenbank.db")
        # 2) Row Factory
        db.row_factory = sqlite3.Row

        # 3) Tabellen anlegen / Spalte prüfen
        db.execute("""
            CREATE TABLE IF NOT EXISTS links (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                kanal TEXT,
                zeitstempel TEXT,
                user_agent TEXT,
                ip_address TEXT
            )
        """)
        db.execute("""
            CREATE TABLE IF NOT EXISTS ip_cooldowns (
                ip TEXT PRIMARY KEY,
                last_submit REAL,
                last_export REAL
            )
        """)
        try:
            db.execute("SELECT last_export FROM ip_cooldowns LIMIT 1")
        except sqlite3.OperationalError:
            db.execute("ALTER TABLE ip_cooldowns ADD COLUMN last_export REAL")
    return db

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, "_database", None)
    if db is not None:
        db.close()

def extract_channel(link):
    pattern = r"(?:https?:\/\/)?(?:www\.)?tiktok\.com\/@([^\/]+)"
    match = re.search(pattern, link.strip())
    if match:
        return match.group(1)
    return None

@app.route("/", methods=["GET", "POST"])
def index():
    return render_template("index.html")

@app.route("/export_csv")
def export_csv():
    db = get_db()
    cursor = db.cursor()
    ip = (request.headers.get("X-Forwarded-For", request.remote_addr) or "Unbekannt").split(",")[0].strip()
    aktuelle_zeit = time.time()

    row_cooldown = cursor.execute("SELECT last_export FROM ip_cooldowns WHERE ip=?", (ip,)).fetchone()
    last_export = row_cooldown["last_export"] if row_cooldown else 0  # dank row_factory => ["last_export"]
    if (aktuelle_zeit - (last_export or 0)) < 30:
        fehlermeldung = "Export nur alle 30 Sekunden möglich."
        total_links = db.execute("SELECT COUNT(*) AS cnt FROM links").fetchone()["cnt"]
        rows = db.execute("SELECT kanal, zeitstempel FROM links ORDER BY id DESC LIMIT 5").fetchall()
        return render_template(
            "fahndungsliste-modal.html",
            fehlermeldung=fehlermeldung,
            total_links=total_links,
            links=rows,
            page=1,
            per_page=5
        )

    rows = cursor.execute("SELECT id, kanal, zeitstempel FROM links ORDER BY id").fetchall()
    csv_data = "id,kanal,zeitstempel\n"
    for row in rows:
        csv_data += f"{row['id']},{row['kanal']},{row['zeitstempel']}\n"

    # last_export aktualisieren
    cursor.execute("""
        INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
        VALUES (
            ?,
            COALESCE((SELECT last_submit FROM ip_cooldowns WHERE ip=?), 0),
            ?
        )
    """, (ip, ip, aktuelle_zeit))
    db.commit()

    return Response(csv_data, mimetype="text/csv", headers={"Content-disposition":"attachment; filename=links_export.csv"})

@app.route("/info")
def info():
    return render_template("info.html")

@app.route("/contact")
def contact():
    return render_template("contact.html")

@app.route("/channel_extractor")
def channel_extractor():
    return render_template("channel-link-extractor.html")

@app.route("/archiv")
def archiv():
    return render_template("archiv.html")

@app.route("/observierung")
def observierung():
    return render_template("observierung.html")

@app.route("/fahndungsliste")
def fahndungsliste():
    return render_template("fahndungsliste.html")

@app.route("/fahndungsliste_db", methods=["GET", "POST"])
def fahndungsliste_db():
    db = get_db()
    page = int(request.args.get("page", 1))
    per_page = 5
    offset = (page - 1) * per_page

    total_links = db.execute("SELECT COUNT(*) AS cnt FROM links").fetchone()["cnt"]
    rows = db.execute("""
        SELECT kanal, zeitstempel
        FROM links
        ORDER BY id DESC
        LIMIT ? OFFSET ?
    """, (per_page, offset)).fetchall()

    fehlermeldung = None

    if request.method == "POST":
        ip = (request.headers.get("X-Forwarded-For", request.remote_addr) or "Unbekannt").split(",")[0].strip()
        aktuelle_zeit = time.time()
        cursor = db.cursor()

        row_cooldown = cursor.execute("SELECT last_submit FROM ip_cooldowns WHERE ip=?", (ip,)).fetchone()
        last_submit = row_cooldown["last_submit"] if row_cooldown else 0
        if (aktuelle_zeit - (last_submit or 0)) < 10:
            fehlermeldung = "Nur alle 10 Sekunden möglich (Fahndungsliste)."
            return render_template(
                "fahndungsliste-modal.html",
                fehlermeldung=fehlermeldung,
                total_links=total_links,
                links=rows,
                page=page,
                per_page=per_page
            )

        eingabe = request.form.get("eingabe_link", "").strip()
        kanal_name = extract_channel(eingabe)
        if not kanal_name:
            fehlermeldung = "Keine gültige TikTok-URL gefunden (Fahndungsliste)."
            return render_template(
                "fahndungsliste-modal.html",
                fehlermeldung=fehlermeldung,
                total_links=total_links,
                links=rows,
                page=page,
                per_page=per_page
            )

        # Duplikat?
        duplikat = cursor.execute("SELECT zeitstempel FROM links WHERE kanal=? LIMIT 1", (kanal_name,)).fetchone()
        if duplikat:
            vorhandenes_datum = duplikat["zeitstempel"]
            fehlermeldung = f"Kanal bereits vorhanden (zuletzt am {vorhandenes_datum})."
            cursor.execute("""
                INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
                VALUES (?, ?, COALESCE((SELECT last_export FROM ip_cooldowns WHERE ip=?), NULL))
            """, (ip, aktuelle_zeit, ip))
            db.commit()

            return render_template(
                "fahndungsliste-modal.html",
                fehlermeldung=fehlermeldung,
                total_links=total_links,
                links=rows,
                page=page,
                per_page=per_page
            )
        else:
            # Neu einfügen
            zeit = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
            user_agent = request.headers.get("User-Agent", "Unbekannt")
            cursor.execute("""
                INSERT INTO links (kanal, zeitstempel, user_agent, ip_address)
                VALUES (?, ?, ?, ?)
            """, (kanal_name, zeit, user_agent, ip))
            db.commit()

            # last_submit aktualisieren
            cursor.execute("""
                INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
                VALUES (?, ?, COALESCE((SELECT last_export FROM ip_cooldowns WHERE ip=?), NULL))
            """, (ip, aktuelle_zeit, ip))
            db.commit()

        return redirect(url_for("fahndungsliste_db", page=page))

    return render_template(
        "fahndungsliste-modal.html",
        fehlermeldung=fehlermeldung,
        total_links=total_links,
        links=rows,
        page=page,
        per_page=per_page
    )

@app.route("/expressmodus")
def expressmodus():
    return render_template("expressmodus.html")
    
@app.route("/Metadaten")
def metadaten():
    return render_template("database_content.html")
    

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
