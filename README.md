# tricktok
Tiktok Archiver   - systematische Erfassung, Erhaltung und Bewertung von Medien auf Tiktok


*T**r**icktok* ist ein Projekt zur systematischen Erfassung, Auswertung und Archivierung von Medieninhalten auf der Plattform Tiktok. Es konzentriert sich auf die fortlaufende Beobachtung und Dokumentation von Beiträgen, die einen extremistischen oder manipulativ-propagandistischen Charakter aufweisen können. Die Infrastruktur setzt sich aus drei separaten Komponenten zusammen. Ein öffentlicher **Webauftritt** präsentiert Informationen, Statistiken und weiteren Daten in einer stilistischen Form **[Adenauer OS](https://tricktok.afd-verbot.de)**. Ein weiteres System deckt die interne **Datenauswertung** ab, in dem automatisierte Prozesse kontinuierlich Metadaten von Tiktok erfassen, Zeitreihen für Likes, Kommentare und Views aufbauen sowie Inhalte auf rechtsextreme oder verfassungsfeindliche Elemente überprüfen. Ein unabhängiges **Archiv** speichert langfristig sämtliche Videos und Bilddateien, um sie für spätere Untersuchungen bereitzustellen.

### Tricktok Zeitreihen

Eine zentrale Funktion von *T**r**icktok*, sind automatisierte Verfahren, die in regelmäßigen Abständen Kanäle und deren Postings auswerten. Dadurch lassen sich sowohl kurzzeitige Trends als auch längerfristige Kampagnen mit möglichen Manipulationsmustern erkennen. 

### Medienverarbeitung

Da Tiktok neben Videos zunehmend Fotostrecken oder Diashows anbietet, wird eine Vielzahl unterschiedlicher Dateiformate durch *T**r**icktok* erfasst. Mit OCR-Texterkennungs-Technologien werden die Inhalte von Tiktok-Photos ausgewertet und sind somit durch Titel und Inhalt durchsuchbar. Gleichzeitig wird die OpenAI-API mit dem Modell whisper-1 eingesetzt, um das gesprochene Wort aus Videosequenzen herauszulösen. Auf diese Weise entsteht eine transkribierte Textbasis, die weitergehend auf Schlüsselbegriffe, verbotene Inhalte oder extremistisches Vokabular untersucht werden kann. Viele Kanäle mit rechtsextremistischer Ausrichtung bedienen sich z.B identischer Audiosequenzen für die Funktion Tiktok-Photos. Diese Nutzungsmuster lassen Rückschlüsse auf gemeinsame Urheber oder koordinierte Kampagnen zu.

### Teilhabe

Eine öffentliche Fahndungsliste ermöglicht es interessierten Nutzerinnen und Nutzern von Tricktok, potenziell auffällige TikTok-Kanäle zu melden. Diese Meldungen fließen anschließend in den automatisierten Erfassungsprozess ein. Gleichwohl kann dadurch das Risiko entstehen, dass einige Personen in großem Umfang unkritische Kanäle eintragen und so den Fokus der Fahndungsliste verwässern.
Im deutschsprachigen Raum lassen sich jedoch häufig wiederkehrende Hashtags und charakteristische Formulierungen beobachten, die auf ein rechtsextremes oder verfassungsfeindliches Gedankengut hindeuten. Indem alle Metadaten zu Videoveröffentlichungen analysiert werden, ist es in vielen Fällen möglich, anhand der Gesamtheit der Inhalte eines Kanals schnell zu erkennen, ob dieser dem rechten Spektrum zuzuordnen ist. Kanäle, die nicht in dieses Muster fallen, werden gezielt ausgeklammert und für die weitere Überwachung ausgeschlossen, indem sie in einer Blacklist vermerkt werden.


### Gewaltenteilung

Durch die Trennung der Serverinfrastruktur in Webauftritt, Datenauswertung und Archiv kann das System skaliert werden. Während die öffentliche Plattform lediglich die aufbereiteten Ergebnisse präsentiert, läuft die eigentliche Erfassung und Analyse in einem geschützten Umfeld, welches stets ausreichend Kapazität bieten muss.

### Stimmungsbild

Langfristig zielt Tricktok darauf ab, die Mechanismen von Falschinformation und extremistischer Propaganda auf Tiktok besser zu verstehen und eine Grundlage für entsprechende Aufklärungen oder gar Strafverfolgung zu liefern.


### Backend Strategie

Die millionenfache automatisierte Auswertung von Medien auf Tiktok bedarf leistungsstarker Infrastruktur und viel Speicherplatz. Die Kosten die durch Nutzung der openAI API mit dem Produkt whisper-1 entstehen sind aktuell nur grob abzuschätzen. Es besteht die Idee auch das Google Produkt Vision für bildbasierte Auswertungen zu verwenden, was weitere Kosten verursachen würde. Das Projekt zielt darauf ab, anhand der Auswertung von etwa 20.000 bis 40.000 Medieninhalten ein Proof-of-Concept zu entwickeln.



Sämtliche im Rahmen des Vorhabens entstandene Software wird in deutscher Sprache unter einer quelloffenen Lizenz auf GitHub veröffentlicht.
Die gesamte Softwareentwicklung erfolgt unter aktiver Verwendung fortgeschrittener Sprachmodelle (LLM´s). 





#### Quellen:

- **[Neuters](https://neuters.de/about)**: Alternative leichtgewichtige Benutzeroberfläche für Reuters.
- **[System.css](https://sakofchit.github.io/system.css/)**: CSS-Bibliothek für retro-inspirierte UI, umgebaut zur Desktop-Simulation.
- **[yt-dlp](https://github.com/yt-dlp/yt-dlp)**: Kommandozeilen-Tool für Audio- und Video-Downloads.
- **[gallery-dl](https://github.com/mikf/gallery-dl)**: Tool zum Herunterladen von Bildgalerien.
- **[wordcloud2](https://r-graph-gallery.com/196-the-wordcloud2-library.html)**: R-Bibliothek zum Erstellen von Wortwolken.
- **[PeerTube](https://github.com/Chocobozzz/PeerTube)**: Föderierte Videohosting-Plattform.
- **[Jupyter](https://github.com/jupyter)**: Python Ökosystem & Datenanalyse