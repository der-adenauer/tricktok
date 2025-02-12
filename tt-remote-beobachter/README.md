## db_link_processor.py

Das Skript namens **db_link_processor.py** ermöglicht eine dezentrale Verarbeitung von Tiktok-Metadaten.
Eine zentrale Datenbank verwaltet alle zur Fahndung gestellten Kanäle und liefert Link von Medieninhalten zurück
Mehrere Geräte können dieses Programm  verwenden, um Metadaten zu gewinnen und anschließend gebündelt in die Datenbank zurückzuführen.
Dieser Ansatz verteilt die Anfragen auf unterschiedliche Endgeräte und reduziert damit IP-basierte Netzsperren. Die verteilte Beschaffung der Metadaten, ermöglichen eine strukturierte Erfassung aller Medien eines Tiktok Kanal.


Die Zugangsdaten zur zentralen Datenbank sind nicht öffentlich verfügbar und werden auf Anfrage an **adenauer@tutamail.com** bereitgestellt.
Eine korrekte Hinterlegung der Daten in einer **.env-Datei ermöglicht** automatisierte Verbindungen mit dem Tricktok-Datenbanksystem.

Ein zyklischer Durchlauf  ruft Metadaten via **yt-dlp** ab und speichert gewonnene Informationen inklusive Zeitreihen in der Datenbank.
Damit entsteht eine fortlaufende Historie von Reichweiten von allen observierten Kanälen, die auf Abruf analysiert werden kann.  
Durch diese Methode entsteht eine fortwährende Erfassung von ausgewählten Tiktok-Inhalten.


## Tricktok Metadata Extraction – Termux Setup

#### 📌 Einführung
Dieses Skript ermöglicht die Extraktion von Metadaten und die Erstellung einer Zeitreihe für Tiktok-Videos. Die Reichweitenentwicklung wird mit Zeitstempel erfasst. Unter **Termux auf Android** kann das Skript direkt ausgeführt werden.

📺 **Demovideo:**  
## 📺 Demo-Video
[DEMO HIER KLICKEN](https://archive.afd-verbot.de/w/4NseT1EUJP64oNDhQfyEkG)

---

### ⚙️ Einrichtung unter Termux

#### 1️⃣ **Termux installieren**
Falls nicht vorhanden, installiere **Termux** aus einer vertrauenswürdigen Quelle.

#### 2️⃣ **Python und Abhängigkeiten installieren**
Führe im Termux-Terminal aus:
```bash
pkg update && pkg upgrade
pkg install python python-pip git
```

#### 3️⃣ **Virtuelle Umgebung (venv) erstellen**
Erstelle eine isolierte Python-Umgebung für das Skript:
```bash
python3 -m venv venv
source venv/bin/activate
```

#### 4️⃣ **Abhängigkeiten installieren**
Installiere alle notwendigen Pakete aus `requirements.txt`:
```bash
pip install -r requirements.txt
```


#### **.env Datei erstellen**

Zugangsdaten müssen angefragt werden.


```bash
DB_HOST=xxx.xxx.xxx.123
DB_PORT=xxxx
DB_NAME=xxxxxxxxxxx
DB_USER=xxxxxxxxxxxxxxx
DB_PASS=xxxxxxxxxxxx
```

#### 5️⃣ **Skript ausführen**
Starte das Crawling-Skript mit:
```bash
python metadata_crawler.py
```

---

### 🔍 **Laufzeit-Überwachung**
Um den aktuellen Status des Skripts zu beobachten, kannst du das Logfile in Echtzeit mit **`tail -f`** verfolgen:
```bash
tail -f logging.log
```

--