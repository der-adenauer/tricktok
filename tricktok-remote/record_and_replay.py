import json
import time
import sys
from pynput import mouse, keyboard

# Globale Zustände
aufzeichnung_aktiv = False
sequenz_daten = []
alle_sequenzen = []
sequenz_index = 0
max_sequenzen = 10

# Zeitstempel für zeitliche Zuordnung
start_zeit = 0.0

# Listener-Instanzen
maus_listener = None
tastatur_listener = None

# JSON-Speicherung mit Logging in der Konsole
def speichere_sequenz(dateiname, daten):
    print(f"\nSpeichervorgang: {dateiname}")
    print("Inhalt der Sequenz:")
    for eintrag in daten:
        print(eintrag)
    with open(dateiname, "w", encoding="utf-8") as f:
        json.dump(daten, f, indent=2, ensure_ascii=False)
    print("Datei wurde gespeichert.\n")

# Mausaktionen protokollieren
def on_move(x, y):
    if aufzeichnung_aktiv:
        zeit_diff = time.time() - start_zeit
        eintrag = {
            "typ": "mouse_move",
            "x": x,
            "y": y,
            "zeit": zeit_diff
        }
        sequenz_daten.append(eintrag)
        print(f"Mausbewegung erfasst: {eintrag}")

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
        print(f"Mausklick erfasst: {eintrag}")

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
        print(f"Maus-Scroll erfasst: {eintrag}")

# Tastaturaktionen protokollieren
def on_press(key):
    global aufzeichnung_aktiv, sequenz_daten, alle_sequenzen, sequenz_index

    # Programm global mit '#' beenden
    if key == keyboard.KeyCode.from_char('#'):
        print("\nBeenden durch '#' erkannt.")
        sys.exit(0)

    # Aufzeichnung starten/stoppen mit '-'
    if key == keyboard.KeyCode.from_char('-'):
        aufzeichnung_umschalten()
        return

    # Replay einer Sequenz durch Druck auf 1..9 oder 0
    # '0' für sequenz_10.json
    # '1'..'9' für sequenz_1.json .. sequenz_9.json
    if hasattr(key, 'char') and key.char in [str(i) for i in range(1,10)] + ["0"]:
        if key.char == "0":
            dateiname = "sequenz_10.json"
        else:
            dateiname = f"sequenz_{key.char}.json"
        wiederhole_sequenz(dateiname)

    # Beim Aufzeichnen Tastendruck erfassen
    if aufzeichnung_aktiv:
        zeit_diff = time.time() - start_zeit
        try:
            taste = key.char
        except AttributeError:
            taste = str(key)
        eintrag = {
            "typ": "key_press",
            "taste": taste,
            "zeit": zeit_diff
        }
        sequenz_daten.append(eintrag)
        print(f"Tastendruck erfasst: {eintrag}")

def on_release(key):
    if aufzeichnung_aktiv:
        zeit_diff = time.time() - start_zeit
        try:
            taste = key.char
        except AttributeError:
            taste = str(key)
        eintrag = {
            "typ": "key_release",
            "taste": taste,
            "zeit": zeit_diff
        }
        sequenz_daten.append(eintrag)
        print(f"Tastenfreigabe erfasst: {eintrag}")

# Aufzeichnung umschalten (Start/Ende)
def aufzeichnung_umschalten():
    global aufzeichnung_aktiv, sequenz_daten, alle_sequenzen, sequenz_index, start_zeit

    if not aufzeichnung_aktiv:
        if sequenz_index >= max_sequenzen:
            print(f"Maximal {max_sequenzen} Sequenzen erreicht. Keine weitere Aufzeichnung möglich.")
            return

        print(f"\nAufzeichnung {sequenz_index + 1} wird gestartet ...")
        aufzeichnung_aktiv = True
        sequenz_daten = []
        start_zeit = time.time()
    else:
        aufzeichnung_aktiv = False
        alle_sequenzen.append(sequenz_daten.copy())
        dateiname = f"sequenz_{sequenz_index + 1}.json"
        speichere_sequenz(dateiname, sequenz_daten)
        sequenz_index += 1
        sequenz_daten = []
        print("Aufzeichnung wurde beendet.\n")

# Wiederholung einer gespeicherten Sequenz
def wiederhole_sequenz(dateiname):
    print(f"\nAusführung der Sequenz aus Datei: {dateiname}")
    try:
        with open(dateiname, "r", encoding="utf-8") as f:
            daten = json.load(f)
    except FileNotFoundError:
        print("Datei nicht gefunden.")
        return

    maus_controller = mouse.Controller()
    tastatur_controller = keyboard.Controller()

    if not daten:
        print("Keine Daten vorhanden.")
        return

    for i, eintrag in enumerate(daten):
        aktueller_zeit = eintrag["zeit"]
        if i == 0:
            vorheriger_zeit = aktueller_zeit
        else:
            vorheriger_zeit = daten[i-1]["zeit"]

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
                print(f"Sondertaste nicht verarbeitbar: {taste_str}")
        elif typ == "key_release":
            taste_str = eintrag["taste"]
            try:
                tastatur_controller.release(taste_str)
            except ValueError:
                print(f"Sondertaste nicht verarbeitbar: {taste_str}")

    print("Sequenz wurde ausgeführt.\n")

def main():
    global maus_listener, tastatur_listener
    print("Programm zur Aufzeichnung von Maus- und Tastatureingaben.")
    print("Beenden mit '#' (globale Taste).")
    print("Aufzeichnung umschalten mit '-'. Maximal 10 Sequenzen möglich.")
    print("Erzeugte JSON-Dateien werden im aktuellen Verzeichnis gespeichert.")
    print("Tasten 1–9 und 0 starten Wiederholung der zugehörigen Sequenzdatei.")

    maus_listener = mouse.Listener(on_move=on_move, on_click=on_click, on_scroll=on_scroll)
    tastatur_listener = keyboard.Listener(on_press=on_press, on_release=on_release)

    maus_listener.start()
    tastatur_listener.start()

    try:
        while True:
            time.sleep(0.1)
    except KeyboardInterrupt:
        print("\nProgrammende durch Tastaturinterrupt")
    finally:
        maus_listener.stop()
        tastatur_listener.stop()

if __name__ == "__main__":
    main()
