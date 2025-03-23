#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import json
import time
import sys
import logging
import asyncio
import threading

from pynput import mouse, keyboard
import websockets

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%Y-%m-%d %H:%M:%S"
)

aufzeichnung_aktiv = False
sequenz_daten = []
alle_sequenzen = []
sequenz_index = 0
max_sequenzen = 10
start_zeit = 0.0

maus_listener = None
tastatur_listener = None

<<<<<<< HEAD
# Sicherheits-Token, analog zum Server
SECRET_TOKEN = "SUPER_SECRET_TOKEN"
=======
# Sichere Token-Konstante (muss mit app.py übereinstimmen)
SICHERHEITS_TOKEN = "jkS89N*skskAHD12_???"

# Bei Bedarf wss:// verwenden, wenn SSL aktiv
SERVER_URL = "ws://tricktok.net:5000/ws"
>>>>>>> 650a500 (client update)

# WebSocket-URL mit SSL und Port 443 via Nginx-Proxy
# Token-Anhang in Query-Param (alternativ Header)
SERVER_URL = f"wss://tricktok.net/ws?token={SECRET_TOKEN}"

def speichere_sequenz(dateiname, daten):
    logging.info(f"Speichervorgang: {dateiname}, Einträge={len(daten)}")
    with open(dateiname, "w", encoding="utf-8") as f:
        json.dump(daten, f, indent=2, ensure_ascii=False)
    logging.info("Datei gespeichert.")

def on_move(x, y):
    if aufzeichnung_aktiv:
        zeit_diff = time.time() - start_zeit
        eintrag = {"typ": "mouse_move", "x": x, "y": y, "zeit": zeit_diff}
        sequenz_daten.append(eintrag)

def on_click(x, y, button, pressed):
    if aufzeichnung_aktiv:
        zeit_diff = time.time() - start_zeit
        eintrag = {
            "typ": "mouse_click",
            "taste": str(button),
            "zustand": "down" if pressed else "up",
            "x": x,
            "y": y,
            "zeit": zeit_diff
        }
        sequenz_daten.append(eintrag)

def on_scroll(x, y, dx, dy):
    if aufzeichnung_aktiv:
        zeit_diff = time.time() - start_zeit
        eintrag = {
            "typ": "mouse_scroll",
            "x": x,
            "y": y,
            "scroll_x": dx,
            "scroll_y": dy,
            "zeit": zeit_diff
        }
        sequenz_daten.append(eintrag)

def on_press(key):
    global aufzeichnung_aktiv, sequenz_daten, alle_sequenzen, sequenz_index
    if key == keyboard.KeyCode.from_char('#'):
        logging.info("Beenden mit '#' initiiert.")
        sys.exit(0)
    if key == keyboard.KeyCode.from_char('-'):
        aufzeichnung_umschalten()
        return
    if hasattr(key, 'char') and key.char in [str(i) for i in range(1,10)] + ["0"]:
        if key.char == "0":
            dateiname = "sequenz_10.json"
        else:
            dateiname = f"sequenz_{key.char}.json"
        wiederhole_sequenz(dateiname)
    if aufzeichnung_aktiv:
        zeit_diff = time.time() - start_zeit
        try:
            taste = key.char
        except AttributeError:
            taste = str(key)
        eintrag = {"typ": "key_press", "taste": taste, "zeit": zeit_diff}
        sequenz_daten.append(eintrag)

def on_release(key):
    if aufzeichnung_aktiv:
        zeit_diff = time.time() - start_zeit
        try:
            taste = key.char
        except AttributeError:
            taste = str(key)
        eintrag = {"typ": "key_release", "taste": taste, "zeit": zeit_diff}
        sequenz_daten.append(eintrag)

def aufzeichnung_umschalten():
    global aufzeichnung_aktiv, sequenz_daten, alle_sequenzen, sequenz_index, start_zeit
    if not aufzeichnung_aktiv:
        if sequenz_index >= max_sequenzen:
            logging.warning("Maximale Sequenzanzahl erreicht. Keine weitere Aufzeichnung möglich.")
            return
        sequenz_index += 1
        logging.info(f"Aufzeichnung {sequenz_index} gestartet.")
        aufzeichnung_aktiv = True
        sequenz_daten.clear()
        start_zeit = time.time()
    else:
        aufzeichnung_aktiv = False
        alle_sequenzen.append(sequenz_daten.copy())
        dateiname = f"sequenz_{sequenz_index}.json"
        speichere_sequenz(dateiname, sequenz_daten)
        logging.info(f"Aufzeichnung {sequenz_index} beendet. Datei: {dateiname}")
        sequenz_daten.clear()

def wiederhole_sequenz(dateiname):
    logging.info(f"Ausführung der Sequenz: {dateiname}")
    try:
        with open(dateiname, "r", encoding="utf-8") as f:
            daten = json.load(f)
    except FileNotFoundError:
        logging.error(f"Datei nicht gefunden: {dateiname}")
        return

    from pynput import mouse, keyboard
    maus_controller = mouse.Controller()
    tastatur_controller = keyboard.Controller()

    if not daten:
        logging.info("Keine Daten vorhanden.")
        return

    for i, eintrag in enumerate(daten):
        aktueller_zeit = eintrag["zeit"]
        vorheriger_zeit = daten[i-1]["zeit"] if i > 0 else aktueller_zeit
        wartezeit = aktueller_zeit - vorheriger_zeit
        time.sleep(max(0, wartezeit))

        typ = eintrag["typ"]
        if typ == "mouse_move":
            maus_controller.position = (eintrag["x"], eintrag["y"])
        elif typ == "mouse_click":
            button_str = eintrag["taste"]
            if "left" in button_str:
                button_obj = mouse.Button.left
            elif "right" in button_str:
                button_obj = mouse.Button.right
            else:
                button_obj = mouse.Button.middle
            if eintrag["zustand"] == "down":
                maus_controller.press(button_obj)
            else:
                maus_controller.release(button_obj)
        elif typ == "mouse_scroll":
            maus_controller.scroll(eintrag["scroll_x"], eintrag["scroll_y"])
        elif typ == "key_press":
            taste_str = eintrag["taste"]
            try:
                tastatur_controller.press(taste_str)
            except ValueError:
                logging.warning(f"Sondertaste nicht verarbeitbar: {taste_str}")
        elif typ == "key_release":
            taste_str = eintrag["taste"]
            try:
                tastatur_controller.release(taste_str)
            except ValueError:
                logging.warning(f"Sondertaste nicht verarbeitbar: {taste_str}")

    logging.info("Sequenz ausgeführt.")

#####################################################################
# WebSocket-Empfang
#####################################################################

async def websocket_empfang():
<<<<<<< HEAD
    logging.info(f"Versuch einer Verbindung: {SERVER_URL}")
    # Beispiel: Komprimierung explizit deaktivieren
    extra_headers = {
        'Sec-WebSocket-Extensions': 'x-no-compression'
    }
=======
    logging.info(f"Verbindung zum Server wird aufgebaut: {SERVER_URL}")
>>>>>>> 650a500 (client update)
    try:
        async with websockets.connect(SERVER_URL, extra_headers=extra_headers) as ws:
            logging.info("WebSocket-Verbindung erfolgreich.")
            while True:
                try:
                    message = await ws.recv()
                    logging.info(f"Server-Nachricht erhalten: {message}")
                    daten = json.loads(message)

                    if daten.get("typ") == "info":
                        logging.info(f"Server-INFO: {daten.get('msg')}")

                    elif daten.get("typ") == "status":
                        logging.info(f"Server-STATUS: aktion_laufend={daten.get('aktion_laufend')}")

                    elif daten.get("typ") == "start_aktion":
                        seq = daten.get("sequenz")
                        if seq:
                            logging.info(f"Starte Replay-Sequenz {seq} (Server-Trigger).")
                            if seq == "10":
                                dateiname = "sequenz_10.json"
                            else:
                                dateiname = f"sequenz_{seq}.json"
                            wiederhole_sequenz(dateiname)

                except websockets.ConnectionClosed:
                    logging.warning("WebSocket-Verbindung geschlossen.")
                    break
    except Exception as e:
        logging.error(f"Fehler bei WebSocket-Verbindung: {e}")

def start_websocket_thread():
    loop = asyncio.new_event_loop()
    asyncio.set_event_loop(loop)
    loop.run_until_complete(websocket_empfang())
    loop.close()

def main():
<<<<<<< HEAD
    logging.info("Lokales Client-Skript gestartet.")
=======
    logging.info("Lokales Client-Skript wird gestartet.")
>>>>>>> 650a500 (client update)
    global maus_listener, tastatur_listener

    maus_listener = mouse.Listener(on_move=on_move, on_click=on_click, on_scroll=on_scroll)
    tastatur_listener = keyboard.Listener(on_press=on_press, on_release=on_release)
    maus_listener.start()
    tastatur_listener.start()

    ws_thread = threading.Thread(target=start_websocket_thread, daemon=True)
    ws_thread.start()

    try:
        while True:
            time.sleep(0.1)
    except KeyboardInterrupt:
<<<<<<< HEAD
        logging.info("Beenden durch KeyboardInterrupt")
=======
        logging.info("Beende durch KeyboardInterrupt.")
>>>>>>> 650a500 (client update)
    finally:
        maus_listener.stop()
        tastatur_listener.stop()
        logging.info("Programm beendet.")

if __name__ == "__main__":
    main()

