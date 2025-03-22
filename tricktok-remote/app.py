#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import os
import asyncio
import logging
from flask import Flask, render_template_string, request
from flask_sock import Sock

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S",
    filename="/home/giraff/tricktok_app.log",  # Pfad ggf. anpassen
    filemode="a"
)

# Sicherheits-Token (fest kodiert oder via Environment-Variable)
SECRET_TOKEN = os.environ.get("TRICKTOK_WS_TOKEN", "SUPER_SECRET_TOKEN")

app = Flask(__name__)
sock = Sock(app)

aktion_laufend = False
verbundene_clients = set()

@app.after_request
def apply_hsts(response):
    # Aktivierung von Strict-Transport-Security (HSTS)
    # Signalisiert dem Browser, dass nur HTTPS verwendet werden darf
    response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains"
    return response

html_seite = r"""
<!DOCTYPE html>
<html lang="de">
<head>
  <meta charset="utf-8">
  <title>Livestream & Steuerung</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <style>
    /* Smartphone-Rahmen */
    .smartphone {
      position: relative;
      width: 360px;
      height: 640px;
      margin: 20px auto;
      border: 16px black solid;
      border-top-width: 60px;
      border-bottom-width: 60px;
      border-radius: 36px;
      background: #f8f8f8;
    }

    .smartphone:before {
      content: '';
      display: block;
      width: 60px;
      height: 5px;
      position: absolute;
      top: -30px;
      left: 50%;
      transform: translate(-50%, -50%);
      background: #333;
      border-radius: 10px;
    }

    .smartphone:after {
      content: '';
      display: block;
      width: 35px;
      height: 35px;
      position: absolute;
      left: 50%;
      bottom: -65px;
      transform: translate(-50%, -50%);
      background: #333;
      border-radius: 50%;
    }

    /* Display-Bereich */
    .smartphone .content {
      position: relative;
      width: 360px;
      height: 640px;
      background: #000;
      overflow: hidden;
    }

    /* Player: doppelte Skalierung */
    #player_id {
      width: 180px;
      height: 320px;
      transform: scale(2);
      transform-origin: 0 0;
    }

    body {
      margin: 0;
      padding: 0;
      font-family: sans-serif;
      background: #fafafa;
      text-align: center;
    }

    .buttons-container {
      width: 360px;
      margin: 10px auto;
      display: flex;
      flex-direction: column;
      align-items: center;
    }
    .buttons-container button {
      width: 100%;
      margin: 5px 0;
      padding: 15px;
      font-size: 20px;
      cursor: pointer;
      border: 1px solid #ccc;
      border-radius: 4px;
      color: #000;
    }

    /* Roter Button (Mitte) */
    .buttons-container button[data-seq="2"] {
      background-color: #e74c3c;
      color: #fff;
    }

    /* Logfenster auf drei Zeilen begrenzt */
    #info {
      width: 360px;
      max-height: 3em; /* ~3 Zeilen */
      margin: 10px auto;
      padding: 10px;
      background: #fff;
      border: 1px solid #ccc;
      font-size: 14px;
      overflow-y: auto;
    }
    #info p {
      margin: 5px 0;
    }

    .wrapper {
      display: inline-block;
      transform-origin: top left;
      text-align: center;
      margin: 0 auto;
    }
  </style>
</head>
<body>

  <div class="wrapper">
    <div class="smartphone">
      <div class="content">
        <!-- OvenPlayer (Livestream) -->
        <div id="player_id"></div>
      </div>
    </div>

    <div class="buttons-container">
      <button data-seq="1">&#9650;</button>
      <button data-seq="2">&#10084;</button>
      <button data-seq="3">&#9660;</button>
    </div>

    <div id="info"></div>
  </div>

  <!-- OvenPlayer einbinden -->
  <script src="./ovenplayer/ovenplayer.js"></script>
  <script>
    const player = OvenPlayer.create('player_id', {
      autoStart: true,
      sources: [
        {
          type: 'webrtc',
          file: 'wss://tricktok.net:3334/app/streamName'
        }
      ]
    });

    let socket;
    let aktion_laufend = false;

    function initialisiereWebSocket() {
      const prot = (location.protocol === "https:") ? "wss://" : "ws://";
      // Token für Verbindung im Header oder Query-Parameter:
      // Hier Beispiel via URL-Parameter: ?token=SUPER_SECRET_TOKEN
      // Alternativ in realen Szenarien dynamische Erzeugung / sessionStorage etc.
      const token = "SUPER_SECRET_TOKEN";
      const wsUrl = prot + location.host + "/ws?token=" + token;

      socket = new WebSocket(wsUrl);

      socket.addEventListener("open", function() {
        zeigeInfo("Verbindung zum Server: OK");
      });

      socket.addEventListener("message", function(event) {
        const daten = JSON.parse(event.data);
        if (daten.typ === "status") {
          aktion_laufend = daten.aktion_laufend;
          aktualisiereButtonStatus();
        } else if (daten.typ === "info") {
          zeigeInfo(daten.msg);
        }
      });

      socket.addEventListener("close", function() {
        zeigeInfo("Verbindung zum Server: geschlossen");
        aktion_laufend = false;
        aktualisiereButtonStatus();
      });
    }

    function aktualisiereButtonStatus() {
      const alleButtons = document.querySelectorAll("button[data-seq]");
      alleButtons.forEach(btn => {
        btn.disabled = aktion_laufend;
      });
    }

    function zeigeInfo(txt) {
      const infoDiv = document.getElementById("info");
      const p = document.createElement("p");
      p.textContent = txt;
      infoDiv.appendChild(p);
      infoDiv.scrollTop = infoDiv.scrollHeight;
    }

    document.addEventListener("DOMContentLoaded", () => {
      initialisiereWebSocket();

      const alleButtons = document.querySelectorAll("button[data-seq]");
      alleButtons.forEach(btn => {
        btn.addEventListener("click", () => {
          const seq = btn.getAttribute("data-seq");
          if (!aktion_laufend && socket && socket.readyState === WebSocket.OPEN) {
            const nachricht = {
              typ: "start_aktion",
              sequenz: seq
            };
            socket.send(JSON.stringify(nachricht));
          }
        });
      });
    });
  </script>

  <!-- Dynamische Skalierung -->
  <script>
    function passeAllesAn() {
      const wrapper = document.querySelector('.wrapper');
      if (!wrapper) return;
      const scaleW = window.innerWidth / wrapper.offsetWidth;
      const scaleH = window.innerHeight / wrapper.offsetHeight;
      const scale = Math.min(scaleW, scaleH);
      wrapper.style.transform = 'scale(' + scale + ')';
    }

    window.addEventListener('resize', passeAllesAn);
    window.addEventListener('load', passeAllesAn);
  </script>
</body>
</html>
"""

@app.route('/')
def index():
    logging.info("HTTP GET / aufgerufen")
    return render_template_string(html_seite)

@sock.route('/ws')
def websocket_kommunikation(ws):
    global aktion_laufend, verbundene_clients

    # Origin-Check (CSRF-Schutz, nur tricktok.net)
    origin = request.headers.get("Origin", "")
    if not origin.startswith("https://tricktok.net"):
        logging.warning("Verbindung abgelehnt: Unzulässiger Origin: %s", origin)
        ws.close()
        return

    # Token prüfen (im Query-String oder Header)
    client_token = request.args.get("token", "")  # Einfaches Beispiel
    if client_token != SECRET_TOKEN:
        logging.warning("WebSocket-Token ungültig oder fehlt.")
        ws.close()
        return

    verbundene_clients.add(ws)
    logging.info("Neuer WebSocket-Client verbunden. Anzahl=%d", len(verbundene_clients))

    # Status-Nachricht bei Verbindungsaufbau
    status_nachricht = json.dumps({
        "typ": "status",
        "aktion_laufend": aktion_laufend
    })
    ws.send(status_nachricht)

    try:
        while True:
            message = ws.receive()
            if message is None:
                break
            logging.info("Empfangen: %s", message)
            daten = json.loads(message)

            if daten.get("typ") == "start_aktion":
                sequenz_nummer = daten.get("sequenz")
                if sequenz_nummer is not None:
                    if aktion_laufend:
                        logging.info("Aktion blockiert (läuft schon).")
                        block_nachricht = {
                            "typ": "info",
                            "msg": "Aktion blockiert: laufende Aktion noch nicht abgeschlossen."
                        }
                        ws.send(json.dumps(block_nachricht))
                    else:
                        aktion_laufend = True
                        info_nachricht = {
                            "typ": "info",
                            "msg": f"Starte Sequenz {sequenz_nummer}."
                        }
                        sende_an_alle(json.dumps(info_nachricht))

                        status_aktiv = {
                            "typ": "status",
                            "aktion_laufend": True
                        }
                        sende_an_alle(json.dumps(status_aktiv))

                        logging.info("Starte Sequenz %s", sequenz_nummer)

                        # Beispielhafte Verzögerung (asynchron)
                        asyncio.run(asyncio.sleep(3))

                        aktion_laufend = False
                        status_ende = {
                            "typ": "status",
                            "aktion_laufend": False
                        }
                        sende_an_alle(json.dumps(status_ende))
                        logging.info("Sequenz %s beendet, Aktion frei.", sequenz_nummer)

    finally:
        if ws in verbundene_clients:
            verbundene_clients.remove(ws)
        logging.info("WebSocket-Client getrennt. Anzahl=%d", len(verbundene_clients))

def sende_an_alle(nachricht):
    entfernte_clients = set()
    for client in verbundene_clients:
        try:
            client.send(nachricht)
        except:
            entfernte_clients.add(client)
    for client in entfernte_clients:
        verbundene_clients.remove(client)

if __name__ == "__main__":
    logging.info("Starte Flask-App auf Port 5000 ...")
    # Gunicorn-Start nicht direkt hier, sondern per:
    #   gunicorn --bind 127.0.0.1:5000 app:app
    app.run(host="0.0.0.0", port=5000, debug=False)
