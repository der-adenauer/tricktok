# tricktok
Tiktok Archiver   - systematische Erfassung, Erhaltung und Bewertung von Medien auf Tiktok

Demo-Version:  https://py.afd-verbot.de/R/


*T**r**icktok** ist ein Projekt zur systematischen Erfassung, Auswertung und Archivierung von Medieninhalten auf der Plattform Tiktok. Es konzentriert sich auf die fortlaufende Beobachtung und Dokumentation von Beiträgen, die einen extremistischen oder manipulativ-propagandistischen Charakter aufweisen können. Die Infrastruktur setzt sich aus drei separaten Komponenten zusammen. Ein öffentlicher **Webauftritt** präsentiert Informationen, Statistiken und weiteren Daten in einer stilistischen Form **[Adenauer OS](https://tricktok.afd-verbot.de)**. Ein weiteres System deckt die interne **Datenauswertung** ab, in dem automatisierte Prozesse kontinuierlich Metadaten von Tiktok erfassen, Zeitreihen für Likes, Kommentare und Views aufbauen sowie Inhalte auf extremistische oder verfassungsfeindliche Elemente überprüfen. Ein unabhängiges **Archiv** speichert langfristig sämtliche Videos und Bilddateien, um sie für spätere Untersuchungen bereitzustellen.

### Tricktok Zeitreihen

Die Funktion Zeitreihen von *T**r**icktok*  erzeugt einen graphischen Verlauf der Reichweite einer Veröffentlichung von Tiktok. Die Grundlage dafür bilden über die Zeit gespeicherte Metadaten von jeder erfassten  Veröffentlichung durch einen Crawler, die in regelmäßigen Abständen Kanäle und deren Postings auswerten. Mit einer Reichweitenstatistik lassen sich kurzzeitige Trends als auch längerfristige Kampagnen mit möglichen Manipulationsmustern erkennen. 

### Medienverarbeitung

Da Tiktok neben Videos zunehmend Fotostrecken oder Diashows anbietet, wird eine Vielzahl unterschiedlicher Dateiformate durch *T**r**icktok* erfasst. Mit OCR-Texterkennungs-Technologien werden die Inhalte von Tiktok-Photos ausgewertet und sind somit durch Titel und Inhalt durchsuchbar. Gleichzeitig wird die OpenAI-API mit dem Modell whisper-1 eingesetzt, um das gesprochene Wort aus Videosequenzen herauszulösen. Auf diese Weise entsteht eine transkribierte Textbasis, die weitergehend auf Schlüsselbegriffe, verbotene Inhalte oder extremistisches Vokabular untersucht werden kann. Viele Kanäle mit extremistischer Ausrichtung bedienen sich z.B identischer Audiosequenzen für die Funktion Tiktok-Photos. Diese Nutzungsmuster lassen Rückschlüsse auf gemeinsame Urheber oder koordinierte Kampagnen zu.

### Teilhabe

Eine öffentliche Fahndungsliste ermöglicht es interessierten Nutzerinnen und Nutzern von Tricktok, potenziell auffällige TikTok-Kanäle zu melden. Diese Meldungen fließen anschließend in den automatisierten Erfassungsprozess ein. Gleichwohl kann dadurch das Risiko entstehen, dass einige Personen in großem Umfang unkritische Kanäle eintragen und so den Fokus der Fahndungsliste verwässern.
Im deutschsprachigen Raum lassen sich jedoch häufig wiederkehrende Hashtags und charakteristische Formulierungen beobachten, die auf ein  verfassungsfeindliches Gedankengut hindeuten. Indem alle Metadaten zu Videoveröffentlichungen analysiert werden, ist es in vielen Fällen möglich, anhand der Gesamtheit der Inhalte eines Kanals schnell zu erkennen, ob dieser dem rechten Spektrum zuzuordnen ist. Kanäle, die nicht in dieses Muster fallen, werden für die weitere Überwachung ausgeschlossen, indem sie in einer Blacklist vermerkt werden.


### Backend Strategie

Die automatisierte Auswertung von Millionen TikTok-Medien erfordert eine verteilte Infrastruktur und große Kapazitäten an Speicherplatz.

Ein zentral verwaltetes PostgreSQL-Datenbanksystem speichert die Metadaten der Medieninhalte, einschließlich der Speicherpfade archivierter und verarbeiteter Dateien. Dezentral agierende Dienste haben abgestufte Lese- und Schreibrechte am Datenbanksystem, was die verteilte, automatisierte Verarbeitung ermöglicht.

Eine Föderation mehrerer Tricktok-Datenbanken soll übergreifenden Informationsaustausch zu ermöglichen.

Tägliche Backups schützen vor Datenverlusten im Triktok-Netzwerk.

### Stimmungsbild

Langfristig zielt Tricktok darauf ab, die Mechanismen von Falschinformation und extremistischer Propaganda auf Tiktok besser zu verstehen und eine Grundlage für entsprechende Aufklärungen oder gar Strafverfolgung zu liefern.


Sämtliche im Rahmen des Vorhabens entstandene Software wird in deutscher Sprache unter einer quelloffenen Lizenz auf GitHub veröffentlicht.
Die gesamte Softwareentwicklung erfolgt unter aktiver Verwendung fortgeschrittener Sprachmodelle (LLM´s). 


### Softwarestack

 **postgresql** - Tricktok-Datenbanksystem

 **Python** – SystemBasics, Crawling   
 
 **ffmprg** - Medeinverarbeitung
 
 **Flask** – Webapplikation   
 
 **R** – interaktive Datenanalysen & grafische Auswertung  
 
 **PeerTube** – Hosting der Medieninhalte  
 
 **OpenAI API (Whisper-1)** – Audio-Transkription aus Videos  
 
 **OCR (Tesseract)** – Texterkennung in Bildern und Videos
 
 **Matter.js** - Contentschleuder


_________

- **[Neuters](https://neuters.de/about)**: Alternative leichtgewichtige Benutzeroberfläche für Reuters.
- **[System.css](https://sakofchit.github.io/system.css/)**: CSS-Bibliothek für retro-inspirierte UI, umgebaut zur Desktop-Simulation.
- **[yt-dlp](https://github.com/yt-dlp/yt-dlp)**: Kommandozeilen-Tool für Audio- und Video-Downloads.
- **[gallery-dl](https://github.com/mikf/gallery-dl)**: Tool zum Herunterladen von Bildgalerien.
- **[wordcloud2](https://r-graph-gallery.com/196-the-wordcloud2-library.html)**: R-Bibliothek zum Erstellen von Wortwolken.
- **[PeerTube](https://github.com/Chocobozzz/PeerTube)**: Föderierte Videohosting-Plattform.
- **[Jupyter](https://github.com/jupyter)**: Python Ökosystem & Datenanalyse
- **[Matter.js](https://www.brm.io/matter-js/):** Javascript-Lib 