import re
import time
import sqlite3
import logging
import random
import os
from datetime import datetime
from flask import (
    Flask, request, g, render_template, redirect,
    url_for, Response, session, jsonify
)

logging.basicConfig(
    filename="app.log",
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s"
)

app = Flask(__name__)
app.secret_key = "irge223442s243426gDhfhadgaewz363u234Assel"


# ----------------------------------------------------------------------------
# Hilfsfunktion zur Umwandlung von Unix-Timestamps in lesbares Datum
# ----------------------------------------------------------------------------
def format_unix_timestamp(ts):
    try:
        return datetime.utcfromtimestamp(float(ts)).strftime("%Y-%m-%d %H:%M:%S")
    except:
        return str(ts)


# ----------------------------------------------------------------------------
# Hilfsfunktionen
# ----------------------------------------------------------------------------

def is_mobile_user_agent(user_agent_string):
    pattern = r"Mobi|Android|iPhone|iPad|Phone"
    return bool(re.search(pattern, user_agent_string, re.IGNORECASE))

@app.context_processor
def inject_is_mobile():
    user_agent = request.headers.get("User-Agent", "")
    return dict(IS_MOBILE=is_mobile_user_agent(user_agent))

@app.route("/benutzer_info")
def benutzer_info():
    user_agent = request.headers.get("User-Agent", "Unbekannt")
    return f"<p style='font-size:12px; color:#666;'>User-Agent: {user_agent}</p>"

@app.route("/session_name")
def session_name():
    if "random_name" not in session:
        names_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "names.txt")
        if not os.path.exists(names_path):
            return "UnbekannterName"
        with open(names_path, "r", encoding="utf-8") as f:
            lines = [line.strip() for line in f if line.strip()]
        if lines:
            session["random_name"] = random.choice(lines)
        else:
            session["random_name"] = "UnbekannterName"
    return session["random_name"]


# ----------------------------------------------------------------------------
# Zentrale DB (datenbank.db)
# ----------------------------------------------------------------------------

def get_db():
    db = getattr(g, "_database", None)
    if db is None:
        db = g._database = sqlite3.connect("datenbank.db")
        db.row_factory = sqlite3.Row

        # Tabellen anlegen / anpassen
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

        # Spalte last_export sicherstellen
        try:
            db.execute("SELECT last_export FROM ip_cooldowns LIMIT 1")
        except sqlite3.OperationalError:
            db.execute("ALTER TABLE ip_cooldowns ADD COLUMN last_export REAL")

        # Neue Spalte last_flag
        try:
            db.execute("SELECT last_flag FROM ip_cooldowns LIMIT 1")
        except sqlite3.OperationalError:
            db.execute("ALTER TABLE ip_cooldowns ADD COLUMN last_flag REAL")

        # Tabelle flag_log
        db.execute("""
            CREATE TABLE IF NOT EXISTS flag_log (
                url TEXT,
                ip TEXT,
                flag_time REAL,
                UNIQUE(url, ip)
            )
        """)

        # Tabelle video_flags
        db.execute("""
            CREATE TABLE IF NOT EXISTS video_flags (
                url TEXT PRIMARY KEY,
                count INTEGER DEFAULT 0
            )
        """)
    return db

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, "_database", None)
    if db is not None:
        db.close()


def extract_channel(link):
    link = link.strip()
    if len(link) > 120:
        return None
    pattern = r"(?:https?:\/\/)?(?:www\.)?tiktok\.com\/@([^\/\?\s]+)"
    match = re.search(pattern, link)
    if match:
        return match.group(1)
    return None


# ----------------------------------------------------------------------------
# Standard-Routen / Index etc.
# ----------------------------------------------------------------------------

@app.route("/", methods=["GET", "POST"])
def index():
    return render_template("index.html")

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

@app.route("/expressmodus")
def expressmodus():
    return render_template("expressmodus.html")

@app.route("/Metadaten")
def metadaten():
    return render_template("database_content.html")

@app.route("/statistiktok")
def statistiktok():
    return render_template("statistiktok.html")

@app.route("/metadatenfilter")
def metadatenfilter():
    return render_template("tt-metadaten-filter.html")

@app.route("/hilfe_extended")
def hilfe_extended():
    return render_template("hilfe_extended.html")


# ----------------------------------------------------------------------------
# Export-Funktionen
# ----------------------------------------------------------------------------

@app.route("/export_csv_db")
def export_csv_db():
    db = get_db()
    cursor = db.cursor()
    ip = (request.headers.get("X-Forwarded-For", request.remote_addr) or "Unbekannt").split(",")[0].strip()
    aktuelle_zeit = time.time()

    row_cooldown = cursor.execute("SELECT last_export FROM ip_cooldowns WHERE ip=?", (ip,)).fetchone()
    last_export = row_cooldown["last_export"] if row_cooldown else 0

    if (aktuelle_zeit - (last_export or 0)) < 30:
        fehlermeldung = "Export nur alle 30 Sekunden möglich."
        total_links = db.execute("SELECT COUNT(*) AS cnt FROM links").fetchone()["cnt"]
        rows = db.execute("SELECT kanal, zeitstempel FROM links ORDER BY id DESC LIMIT 5").fetchall()
        # Zeitstempel umwandeln
        converted_rows = []
        for row in rows:
            row_d = dict(row)
            row_d["zeitstempel"] = format_unix_timestamp(row_d["zeitstempel"])
            converted_rows.append(row_d)
        rows = converted_rows

        return render_template(
            "fahndungsliste-modal.html",
            fehlermeldung=fehlermeldung,
            total_links=total_links,
            links=rows,
            page=1,
            per_page=5
        )

    rows = cursor.execute("SELECT id, kanal, zeitstempel FROM links ORDER BY id").fetchall()
    # Zeitstempel umwandeln
    csv_data = "id,kanal,zeitstempel\n"
    for row in rows:
        csv_data += f"{row['id']},{row['kanal']},{format_unix_timestamp(row['zeitstempel'])}\n"

    cursor.execute("""
        INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
        VALUES (
            ?,
            COALESCE((SELECT last_submit FROM ip_cooldowns WHERE ip=?), 0),
            ?
        )
    """, (ip, ip, aktuelle_zeit))
    db.commit()

    return Response(
        csv_data,
        mimetype="text/csv",
        headers={"Content-disposition": "attachment; filename=links_export.csv"}
    )

@app.route("/export_csv_mobile")
def export_csv_mobile():
    db = get_db()
    cursor = db.cursor()
    ip = (request.headers.get("X-Forwarded-For", request.remote_addr) or "Unbekannt").split(",")[0].strip()
    aktuelle_zeit = time.time()

    row_cooldown = cursor.execute("SELECT last_export FROM ip_cooldowns WHERE ip=?", (ip,)).fetchone()
    last_export = row_cooldown["last_export"] if row_cooldown else 0

    if (aktuelle_zeit - (last_export or 0)) < 30:
        fehlermeldung = "Export nur alle 30 Sekunden möglich."
        total_links = db.execute("SELECT COUNT(*) AS cnt FROM links").fetchone()["cnt"]
        rows = db.execute("SELECT kanal, zeitstempel FROM links ORDER BY id DESC LIMIT 5").fetchall()
        # Zeitstempel umwandeln
        converted_rows = []
        for row in rows:
            row_d = dict(row)
            row_d["zeitstempel"] = format_unix_timestamp(row_d["zeitstempel"])
            converted_rows.append(row_d)
        rows = converted_rows

        return render_template(
            "fahndungsliste-mobile.html",
            fehlermeldung=fehlermeldung,
            total_links=total_links,
            links=rows,
            page=1,
            per_page=5
        )

    rows = cursor.execute("SELECT id, kanal, zeitstempel FROM links ORDER BY id").fetchall()
    # Zeitstempel umwandeln
    csv_data = "id,kanal,zeitstempel\n"
    for row in rows:
        csv_data += f"{row['id']},{row['kanal']},{format_unix_timestamp(row['zeitstempel'])}\n"

    cursor.execute("""
        INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
        VALUES (
            ?,
            COALESCE((SELECT last_submit FROM ip_cooldowns WHERE ip=?), 0),
            ?
        )
    """, (ip, ip, aktuelle_zeit))
    db.commit()

    return Response(
        csv_data,
        mimetype="text/csv",
        headers={"Content-disposition": "attachment; filename=links_export.csv"}
    )


# ----------------------------------------------------------------------------
# Fahndungsliste
# ----------------------------------------------------------------------------

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

    # Zeitstempel umwandeln, bevor an Template übergeben
    converted_rows = []
    for r in rows:
        r_dict = dict(r)
        r_dict["zeitstempel"] = format_unix_timestamp(r_dict["zeitstempel"])
        converted_rows.append(r_dict)
    rows = converted_rows

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

        duplikat = cursor.execute(
            "SELECT zeitstempel FROM links WHERE kanal=? LIMIT 1",
            (kanal_name,)
        ).fetchone()

        if duplikat:
            vorhandenes_datum = format_unix_timestamp(duplikat["zeitstempel"])
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
            # Hier wird nun ein Unix-Timestamp gespeichert
            zeit = time.time()
            user_agent = request.headers.get("User-Agent", "Unbekannt")

            cursor.execute("""
                INSERT INTO links (kanal, zeitstempel, user_agent, ip_address)
                VALUES (?, ?, ?, ?)
            """, (kanal_name, zeit, user_agent, ip))
            db.commit()

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

@app.route("/fahndungsliste", methods=["GET", "POST"])
def fahndungsliste_mobile():
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

    # Zeitstempel umwandeln, bevor an Template übergeben
    converted_rows = []
    for r in rows:
        r_dict = dict(r)
        r_dict["zeitstempel"] = format_unix_timestamp(r_dict["zeitstempel"])
        converted_rows.append(r_dict)
    rows = converted_rows

    fehlermeldung = None

    if request.method == "POST":
        ip = (request.headers.get("X-Forwarded-For", request.remote_addr) or "Unbekannt").split(",")[0].strip()
        aktuelle_zeit = time.time()
        cursor = db.cursor()

        row_cooldown = cursor.execute("SELECT last_submit FROM ip_cooldowns WHERE ip=?", (ip,)).fetchone()
        last_submit = row_cooldown["last_submit"] if row_cooldown else 0

        if (aktuelle_zeit - (last_submit or 0)) < 10:
            fehlermeldung = "Nur alle 10 Sekunden möglich."
            return render_template(
                "fahndungsliste-mobile.html",
                fehlermeldung=fehlermeldung,
                total_links=total_links,
                links=rows,
                page=page,
                per_page=per_page
            )

        eingabe = request.form.get("eingabe_link", "").strip()
        kanal_name = extract_channel(eingabe)
        if not kanal_name:
            fehlermeldung = "Keine gültige TikTok-URL gefunden."
            return render_template(
                "fahndungsliste-mobile.html",
                fehlermeldung=fehlermeldung,
                total_links=total_links,
                links=rows,
                page=page,
                per_page=per_page
            )

        duplikat = cursor.execute(
            "SELECT zeitstempel FROM links WHERE kanal=? LIMIT 1",
            (kanal_name,)
        ).fetchone()

        if duplikat:
            vorhandenes_datum = format_unix_timestamp(duplikat["zeitstempel"])
            fehlermeldung = f"Kanal bereits vorhanden (zuletzt am {vorhandenes_datum})."
            cursor.execute("""
                INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
                VALUES (?, ?, COALESCE((SELECT last_export FROM ip_cooldowns WHERE ip=?), NULL))
            """, (ip, aktuelle_zeit, ip))
            db.commit()

            return render_template(
                "fahndungsliste-mobile.html",
                fehlermeldung=fehlermeldung,
                total_links=total_links,
                links=rows,
                page=page,
                per_page=per_page
            )
        else:
            # Hier wird nun ein Unix-Timestamp gespeichert
            zeit = time.time()
            user_agent = request.headers.get("User-Agent", "Unbekannt")

            cursor.execute("""
                INSERT INTO links (kanal, zeitstempel, user_agent, ip_address)
                VALUES (?, ?, ?, ?)
            """, (kanal_name, zeit, user_agent, ip))
            db.commit()

            cursor.execute("""
                INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export)
                VALUES (?, ?, COALESCE((SELECT last_export FROM ip_cooldowns WHERE ip=?), NULL))
            """, (ip, aktuelle_zeit, ip))
            db.commit()

        return redirect(url_for("fahndungsliste_mobile", page=page))

    return render_template(
        "fahndungsliste-mobile.html",
        fehlermeldung=fehlermeldung,
        total_links=total_links,
        links=rows,
        page=page,
        per_page=per_page
    )


# ----------------------------------------------------------------------------
# Flag / Video Feature
# ----------------------------------------------------------------------------

@app.route("/flag_video", methods=["POST"])
def flag_video():
    db = get_db()
    cursor = db.cursor()

    video_url = request.form.get("video_url", "")
    page = request.form.get("page", "1")
    query = request.form.get("query", "")

    ip = (request.headers.get("X-Forwarded-For", request.remote_addr) or "Unbekannt").split(",")[0].strip()
    aktuelle_zeit = time.time()

    row_cooldown = cursor.execute("SELECT last_flag FROM ip_cooldowns WHERE ip=?", (ip,)).fetchone()
    last_flag = row_cooldown["last_flag"] if row_cooldown and row_cooldown["last_flag"] else 0

    if (aktuelle_zeit - last_flag) < 300:
        return redirect(url_for("video_feature", q=query, page=page, msg="FLAG-COOLDOWN"))

    row_flag_log = db.execute(
        "SELECT COUNT(*) as cnt FROM flag_log WHERE ip=? AND url=?",
        (ip, video_url)
    ).fetchone()
    if row_flag_log and row_flag_log["cnt"] > 0:
        return redirect(url_for("video_feature", q=query, page=page, msg="ALREADY_FLAGGED"))

    cursor.execute("""
        INSERT INTO flag_log (url, ip, flag_time)
        VALUES (?, ?, ?)
    """, (video_url, ip, aktuelle_zeit))

    row_flags = db.execute("SELECT count FROM video_flags WHERE url=?", (video_url,)).fetchone()
    if row_flags:
        new_count = row_flags["count"] + 1
        cursor.execute("UPDATE video_flags SET count=? WHERE url=?", (new_count, video_url))
    else:
        cursor.execute("INSERT INTO video_flags (url, count) VALUES (?, ?)", (video_url, 1))

    cursor.execute("""
        INSERT OR REPLACE INTO ip_cooldowns (ip, last_submit, last_export, last_flag)
        VALUES (
            ?,
            COALESCE((SELECT last_submit FROM ip_cooldowns WHERE ip=?), 0),
            COALESCE((SELECT last_export FROM ip_cooldowns WHERE ip=?), 0),
            ?
        )
    """, (ip, ip, ip, aktuelle_zeit))
    db.commit()

    return redirect(url_for("video_feature", q=query, page=page, msg="FLAGGED_OK"))

@app.route("/video_feature", methods=["GET"])
def video_feature():
    query = request.args.get("q", "").strip()
    msg = request.args.get("msg", "")
    page = int(request.args.get("page", 1))

    per_page = 10
    offset = (page - 1) * per_page

    conn_new = sqlite3.connect("filtered_tiktok_media.db")
    conn_new.row_factory = sqlite3.Row
    cursor = conn_new.cursor()

    condition = ""
    params = []
    if query:
        condition = "WHERE title LIKE ? OR url LIKE ? OR uploader LIKE ?"
        params = [f"%{query}%", f"%{query}%", f"%{query}%"]

    total_query = f"SELECT COUNT(*) as cnt FROM media_info {condition}"
    total_videos = cursor.execute(total_query, params).fetchone()["cnt"]

    data_query = f"""
        SELECT
            new_id,
            title,
            creation_date,
            screenshot_thumbnail_path,
            embedded_link,
            url,
            uploader
        FROM media_info
        {condition}
        ORDER BY new_id DESC
        LIMIT ? OFFSET ?
    """
    cursor.execute(data_query, params + [per_page, offset])
    rows = cursor.fetchall()
    conn_new.close()

    db = get_db()
    data_list = []
    for row in rows:
        row_dict = dict(row)
        vid_url = row_dict["url"]
        f_row = db.execute("SELECT count FROM video_flags WHERE url=?", (vid_url,)).fetchone()
        row_dict["flag_count"] = f_row["count"] if f_row else 0
        data_list.append(row_dict)

    return render_template(
        "video_feature.html",
        query=query,
        msg=msg,
        total_videos=total_videos,
        videos=data_list,
        page=page,
        per_page=per_page
    )

@app.route("/video_feature_load_more", methods=["GET"])
def video_feature_load_more():
    query = request.args.get("q", "").strip()
    start_index = int(request.args.get("start", 0))

    conn_new = sqlite3.connect("filtered_tiktok_media.db")
    conn_new.row_factory = sqlite3.Row
    cursor = conn_new.cursor()

    condition = ""
    params = []
    if query:
        condition = "WHERE title LIKE ? OR url LIKE ? OR uploader LIKE ?"
        params = [f"%{query}%", f"%{query}%", f"%{query}%"]

    data_query = f"""
        SELECT
            new_id,
            title,
            creation_date,
            screenshot_thumbnail_path,
            embedded_link,
            url,
            uploader
        FROM media_info
        {condition}
        ORDER BY new_id DESC
        LIMIT 10 OFFSET ?
    """
    cursor.execute(data_query, params + [start_index])
    rows = cursor.fetchall()
    conn_new.close()

    db = get_db()
    results = []
    for row in rows:
        row_dict = dict(row)
        vid_url = row_dict["url"]
        f_row = db.execute("SELECT count FROM video_flags WHERE url=?", (vid_url,)).fetchone()
        row_dict["flag_count"] = f_row["count"] if f_row else 0
        results.append(row_dict)

    return jsonify(results)


# ----------------------------------------------------------------------------
# Separates DB-Handle für "gallery_dl_extras-Copy3.db"
# ----------------------------------------------------------------------------

def get_db_gallery():
    db = getattr(g, "_gallery_database", None)
    if db is None:
        db = g._gallery_database = sqlite3.connect("filtered_gallery_dl_extras.db")
        db.row_factory = sqlite3.Row
    return db

@app.teardown_appcontext
def close_gallery_db(exception):
    db = getattr(g, "_gallery_database", None)
    if db is not None:
        db.close()


# ----------------------------------------------------------------------------
# Gallery Feature
# ----------------------------------------------------------------------------

@app.route("/gallery_feature", methods=["GET"])
def gallery_feature():
    """
    Zeigt Datensätze aus media_metadata_extras, passt Pfade an
    und konvertiert den Unix-Timestamp in ein lesbares Format.
    Berücksichtigt dabei das Escaping von '#' und '[' / ']' etc.
    """
    query = request.args.get("q", "").strip()
    page = int(request.args.get("page", 1))
    msg = request.args.get("msg", "")

    per_page = 10
    offset = (page - 1) * per_page

    conn_gallery = get_db_gallery()
    cursor = conn_gallery.cursor()

    where_clause = ""
    params = []
    if query:
        where_clause = """
            WHERE title LIKE ?
               OR description LIKE ?
               OR url LIKE ?
               OR uploader LIKE ?
        """
        wildcard = f"%{query}%"
        params = [wildcard, wildcard, wildcard, wildcard]

    total_sql = f"SELECT COUNT(*) as cnt FROM media_metadata_extras {where_clause}"
    total_count = cursor.execute(total_sql, params).fetchone()["cnt"]

    data_sql = f"""
        SELECT
            id,
            url,
            title,
            description,
            timestamp,
            mediapath
        FROM media_metadata_extras
        {where_clause}
        ORDER BY timestamp DESC
        LIMIT ? OFFSET ?
    """
    rows = cursor.execute(data_sql, params + [per_page, offset]).fetchall()

    result_list = []
    for row in rows:
        row_dict = dict(row)

        # Unix-Timestamp => lesbares Format
        raw_ts = row_dict.get("timestamp", None)
        if raw_ts:
            try:
                ts_int = int(raw_ts)
                dt = datetime.utcfromtimestamp(ts_int)
                row_dict["human_date"] = dt.strftime("%Y-%m-%d %H:%M:%S")
            except:
                row_dict["human_date"] = str(raw_ts)
        else:
            row_dict["human_date"] = ""

        # mediapath => Pfade; multiline
        raw_paths = row_dict.get("mediapath") or ""
        lines = [ln.strip() for ln in raw_paths.split("\n") if ln.strip()]

        mapped_paths = []
        for ln in lines:
            if ln.startswith("./gallery-dl/tiktok/"):
                # subpath = e.g. "gruenengegner3.0/TikTok photo #7468...."
                subpath = ln[len("./gallery-dl/tiktok/"):]
                # => "https://py.afd-verbot.de/tiktok/" + escaped(subpath)
                from urllib.parse import quote
                subpath_escaped = quote(subpath, safe="/")
                final_url = "https://py.afd-verbot.de/tiktok/" + subpath_escaped
                mapped_paths.append(final_url)
            else:
                mapped_paths.append(ln)

        row_dict["media_files"] = mapped_paths
        result_list.append(row_dict)

    conn_gallery.close()

    return render_template(
        "gallery_feature.html",
        query=query,
        msg=msg,
        total_count=total_count,
        items=result_list,
        page=page,
        per_page=per_page
    )

@app.route("/gallery_feature_load_more", methods=["GET"])
def gallery_feature_load_more():
    """
    AJAX-Route: "Mehr laden" => nächste 10 Einträge
    Pfade anpassen wie in gallery_feature.
    """
    query = request.args.get("q", "").strip()
    start_index = int(request.args.get("start", 0))

    conn_gallery = get_db_gallery()
    conn_gallery.row_factory = sqlite3.Row
    cursor = conn_gallery.cursor()

    where_clause = ""
    params = []
    if query:
        where_clause = """
            WHERE title LIKE ?
               OR description LIKE ?
               OR url LIKE ?
               OR uploader LIKE ?
        """
        wildcard = f"%{query}%"
        params = [wildcard, wildcard, wildcard, wildcard]

    data_sql = f"""
        SELECT
            id,
            url,
            title,
            description,
            timestamp,
            mediapath
        FROM media_metadata_extras
        {where_clause}
        ORDER BY timestamp DESC
        LIMIT 10 OFFSET ?
    """
    rows = cursor.execute(data_sql, params + [start_index]).fetchall()

    results = []
    from urllib.parse import quote

    for row in rows:
        row_dict = dict(row)
        raw_ts = row_dict.get("timestamp", None)
        if raw_ts:
            try:
                ts_int = int(raw_ts)
                dt = datetime.utcfromtimestamp(ts_int)
                row_dict["human_date"] = dt.strftime("%Y-%m-%d %H:%M:%S")
            except:
                row_dict["human_date"] = str(raw_ts)
        else:
            row_dict["human_date"] = ""

        raw_paths = row_dict.get("mediapath") or ""
        lines = [ln.strip() for ln in raw_paths.split("\n") if ln.strip()]

        mapped_paths = []
        for ln in lines:
            if ln.startswith("./gallery-dl/tiktok/"):
                subpath = ln[len("./gallery-dl/tiktok/"):]
                subpath_escaped = quote(subpath, safe="/")
                final_url = "https://py.afd-verbot.de/tiktok/" + subpath_escaped
                mapped_paths.append(final_url)
            else:
                mapped_paths.append(ln)

        row_dict["media_files"] = mapped_paths
        results.append(row_dict)

    conn_gallery.close()
    return jsonify(results)


# ----------------------------------------------------------------------------
# App Start
# ----------------------------------------------------------------------------

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, debug=True)
