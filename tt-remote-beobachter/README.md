### db_link_processor.py

Das Skript namens **db_link_processor.py** ermöglicht eine dezentrale Verarbeitung von Tiktok-Metadaten.
Eine zentrale Datenbank verwaltet alle zur Fahndung gestellten Kanäle und liefert Link von Medieninhalten zurück
Mehrere Geräte können dieses Programm  verwenden, um Metadaten zu gewinnen und anschließend gebündelt in die Datenbank zurückzuführen.
Dieser Ansatz verteilt die Anfragen auf unterschiedliche Endgeräte und reduziert damit IP-basierte Netzsperren.


Die Zugangsdaten zur zentralen Datenbank sind nicht öffentlich verfügbar und werden auf Anfrage an **adenauer@tutamail.com** bereitgestellt.
Eine korrekte Hinterlegung der Daten in einer **.env-Datei ermöglicht** automatisierte Verbindungen.

Ein zyklischer Durchlauf  ruft Metadaten via **yt-dlp** ab und speichert gewonnene Informationen inklusive Zeitreihen in der Datenbank.
 Damit entsteht eine fortlaufende Historie von Reichweiten und Interaktionen, die auf Abruf analysiert werden kann. Dezentrale Abfragen verringern Ausfallrisiken und erschweren IP-basierte Sperrungen. Durch diese Methode entsteht eine fortwährende Erfassung von Tiktok-Inhalten genutzt wird.
