#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# ==================================================
# Shiny-App mit:
#   - 14 Sektionen, einzeln dargestellt
#   - Navigation über < zurück / weiter >
#   - Navbar (Top-Bar) sticky am oberen Rand
#   - Hamburger-Menü öffnet von links
#   - Reload-Button und Logo rechts
#   - Keine globalen Scrollbalken (Overflow hidden)
#   - Metadaten / Anheuern / Impressum: Text mittig (Blocksatz)
#   - Wechselanimation: nächste Seite fällt von oben herab (SlideDown)
#   - In den meisten Sektionen 10% Abstand (links/rechts)
#   - Adenauer OS / Fahndungsliste / Contentschleuder: füllen ganzen Bildschirm (unterhalb der Top-Bar)
#   - 30s Cooldown für alle CSV-Downloads
# ==================================================

options(shiny.fullstacktrace = TRUE)
options(shiny.error = traceback)
options(shiny.sanitize.errors = FALSE)
options(shiny.trace = TRUE)
options(shiny.reactlog = TRUE)

library(shiny)
library(DBI)
library(RPostgres)
library(dplyr)
library(lubridate)
library(markdown)
library(dotenv)

cat("==== START APP SCRIPT ====\n")

# -------------------------------------------------------
# Globale Variablen für 30s-Cooldown (für alle Nutzer)
# -------------------------------------------------------
LAST_DOWNLOAD_TIME <- as.numeric(Sys.time()) - 9999  
COOLDOWN_SECONDS   <- 30

# -------------------------------------------------------
# Hilfsfunktionen: Datenbank-Abfragen
# -------------------------------------------------------
lade_links <- function(con) {
  query <- "SELECT id, url, inserted_at, processed FROM links ORDER BY id DESC"
  df <- dbGetQuery(con, query)
  cat("[lade_links] Zeilenanzahl:", nrow(df), "\n")
  df
}

lade_media_metadata <- function(con) {
  query <- "
    SELECT
      id, url, title, description, duration, view_count,
      like_count, repost_count, comment_count, uploader,
      uploader_id, channel, channel_id, channel_url, track,
      album, artists, timestamp, extractor
    FROM media_metadata
    ORDER BY id DESC
  "
  df <- dbGetQuery(con, query)
  cat("[lade_media_metadata] Zeilenanzahl:", nrow(df), "\n")
  if ("timestamp" %in% names(df)) {
    df$timestamp <- as.numeric(df$timestamp)
  }
  df
}

lade_media_time_series <- function(con) {
  query <- "
    SELECT
      series_id, url, view_count, like_count, repost_count,
      comment_count, recorded_at
    FROM media_time_series
    ORDER BY series_id DESC
  "
  df <- dbGetQuery(con, query)
  cat("[lade_media_time_series] Zeilenanzahl:", nrow(df), "\n")
  df
}

# -------------------------------------------------------
# Benutzeroberfläche
# -------------------------------------------------------
ui <- fluidPage(
  style = "margin:0; padding:0;",

  tags$head(
    tags$meta(
      name    = "viewport",
      content = "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"
    ),

    # JavaScript (Steuerung: Überschriften, Hamburger-Menü, Seitenwechsel)
    tags$script(HTML("
      var currentSectionIndex = 0;
      var sections = [];
      var sectionTitles = [
        'Start',
        'Einführung',
        'Adenauer OS',
        'Fahndung',
        'Metadaten',
        'Zeitreihen',
        'Statistiktok',
        'Hashtag',
        'Contentschleuder',
        'Photo-Archiv',
        'Video-Archiv',
        'Beweisführung',
        'Anheuern',
        'Impressum'
      ];

      function openNav(){
        var sn = document.getElementById('mySidenav');
        if(sn) sn.style.width = '250px';
      }
      function closeNav(){
        var sn = document.getElementById('mySidenav');
        if(sn) sn.style.width = '0';
      }
      document.addEventListener('click', function(e){
        var sidenav = document.getElementById('mySidenav');
        var hamburgerBtn = document.getElementById('hamburgerBtn');
        if(sidenav && hamburgerBtn && !sidenav.contains(e.target) && !hamburgerBtn.contains(e.target)){
          closeNav();
        }
      });

      document.addEventListener('DOMContentLoaded', function(){
        sections = document.getElementsByClassName('sectionBlock');
        zeigeAktiveSektion(0);
      });

      function zeigeAktiveSektion(index){
        if(index < 0 || index >= sections.length){ return; }
        for(var i=0; i<sections.length; i++){
          sections[i].classList.remove('activeSection');
        }
        sections[index].classList.add('activeSection');
        currentSectionIndex = index;
        var heading = document.getElementById('currentHeading');
        if(heading) heading.textContent = sectionTitles[index];
      }

      function geheVor(){
        if(currentSectionIndex < sections.length - 1){
          zeigeAktiveSektion(currentSectionIndex + 1);
        }
      }
      function geheZurueck(){
        if(currentSectionIndex > 0){
          zeigeAktiveSektion(currentSectionIndex - 1);
        }
      }
    ")),

    # CSS
    tags$style(HTML("
      html, body {
        margin: 0;
        padding: 0;
        overflow: hidden; 
        font-family: sans-serif;
        background-color: #fff;
      }

      /* Top-Bar: sticky Navbar */
      .topBar {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        z-index: 10002;
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 5px 10px;
        background-color: #fff;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      .topBarLeft {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      .topBarRight {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      #hamburgerBtn {
        border: none;
        background-color: transparent;
        font-size: 28px;
        cursor: pointer;
      }
      #currentHeading {
        font-size: 20px;
        font-weight: bold;
      }
      .reloadIcon {
        width: 40px;
        height: 40px;
        background-color: #ddd;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        transition: transform 0.3s;
        font-size: 20px;
      }
      .reloadIcon:hover {
        transform: rotate(360deg);
      }
      #logoImage {
        width: 100px;
        height: auto;
      }

      /* Seitliche Navigation (nun von links) */
      .sidenav {
        height: 100%;
        width: 0;
        position: fixed;
        z-index: 10000;
        top: 0;
        left: 0; /* statt right: 0 */
        background-color: rgba(255,255,255,0.95);
        overflow-x: hidden;
        transition: 0.3s;
        padding-top: 60px; /* Platz unter dem oberen Rand */
      }
      .sidenav a {
        padding: 8px 8px 8px 16px;
        text-decoration: none;
        font-size: 18px;
        color: #000;
        display: block;
        font-weight: bold;
        transition: 0.3s;
      }
      .sidenav a:hover {
        background-color: #ddd;
      }
      .sidenav .closebtn {
        position: absolute;
        top: 0;
        left: 210px; /* So ist das X nah am rechten Rand des aufgeklappten Menüs */
        font-size: 40px;
      }

      /* Buttons unten rechts */
      .navButtons {
        position: fixed;
        bottom: 10px;
        right: 10px;
        z-index: 10003;
        display: flex;
        gap: 10px;
      }
      .navButton {
        padding: 10px 15px;
        background-color: #444;
        color: #fff;
        border: none;
        cursor: pointer;
        font-size: 16px;
        border-radius: 4px;
      }
      .navButton:hover {
        background-color: #555;
      }

      /* SectionBlock: füllt den Bereich UNTER der Top-Bar */
      .sectionBlock {
        position: absolute;
        top: 60px; /* Top-Bar-Höhe anpassen */
        left: 0;
        width: 100%;
        height: calc(100vh - 60px); 
        visibility: hidden;
        opacity: 0;
        transform: translateY(-100%);
        transition: transform 0.6s ease, opacity 0.6s ease, visibility 0.6s;
        overflow: hidden;
      }
      .sectionBlock.activeSection {
        visibility: visible;
        opacity: 1;
        transform: translateY(0);
      }

      /* Inhalt: 10% Rand, mobil weniger (Standard) */
      .sectionContent {
        padding-top: 30px; 
        padding-bottom: 0; 
        margin-left: 10%;
        margin-right: 10%;
        text-align: left;
        height: calc(100% - 30px); /* Bisschen Abstand oben */
      }
      @media (max-width: 768px){
        .sectionContent {
          margin-left: 3%;
          margin-right: 3%;
        }
      }

      /* Farbschema Beispiel */
      #section_start       { background-color: #f9ceb2; }
      #section_intro       { background-color: #ffffff; }
      #section_adenaueros  { background-color: #cccccc; }
      #section_fahndung    { background-color: #cccccc; }
      #section_meta        { background-color: #ffffff; }
      #section_zeitreihen  { background-color: #ffffff; }
      #section_iframeExtra { background-color: #ffffff; }
      #section_hashtag     { background-color: #ffffff; }
      #section_medienholen { background-color: #cccccc; }
      #section_photoarchiv { background-color: #ffffff; }
      #section_videoarchiv { background-color: #ffffff; }
      #section_reiter2     { background-color: #ffffff; }
      #section_anheuern    { background-color: #ffffff; }
      #section_impressum   { background-color: #ffffff; }

      /* Adenauer OS / Fahndungsliste / Contentschleuder = voller Bildschirm unterhalb Top-Bar */
      #section_adenaueros .sectionContent,
      #section_fahndung   .sectionContent,
      #section_medienholen .sectionContent {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
      }
      #section_adenaueros .iframe-wrapper,
      #section_fahndung   .iframe-wrapper,
      #section_medienholen .iframe-wrapper {
        width: 100%;
        height: 100%;
      }

      /* Metadaten / Anheuern / Impressum zentriert + Blocksatz */
      #section_meta .sectionContent,
      #section_anheuern .sectionContent,
      #section_impressum .sectionContent {
        text-align: justify;
      }

      /* Download-Buttons */
      .exportButtons {
        text-align: center;
        margin: 20px 0;
      }
      .exportButtons button {
        margin: 0 10px;
      }

      /* Markdown-Container */
      .markdown-container {
        margin-top: 20px;
        max-width: 800px;
        margin-left: auto;
        margin-right: auto;
      }

      /* Standard IFrame-Wrapper */
      .iframe-wrapper {
        width: 100%;
        height: 100%;
      }
      .iframe-wrapper iframe {
        width: 100%;
        height: 100%;
        border: none;
        display: block;
      }

      /* Mobil: leichte Anpassungen */
      @media (max-width: 768px){
        .sectionBlock {
          top: 50px; 
          height: calc(100vh - 50px);
        }
        #logoImage {
          width: 80px;
        }
        #currentHeading {
          font-size: 16px;
        }
        .navButton {
          font-size: 14px;
          padding: 8px 12px;
        }
        .reloadIcon {
          width: 35px;
          height: 35px;
          font-size: 18px;
        }
      }
    "))
  ),

  # Obere Leiste
  div(
    class = "topBar",
    div(
      class = "topBarLeft",
      tags$button(
        id = "hamburgerBtn",
        HTML("&#9776;"),
        onclick = "openNav()"
      ),
      div(id = "currentHeading", "Start")
    ),
    div(
      class = "topBarRight",
      div(
        class = "reloadIcon",
        HTML("&#x21bb;"),
        onclick = "location.reload();"
      ),
      tags$img(
        id = "logoImage",
        src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg"
      )
    )
  ),

  # Navigations-Buttons (unten rechts)
  div(
    class = "navButtons",
    tags$button(class = "navButton", "< zurück", onclick = "geheZurueck()"),
    tags$button(class = "navButton", "weiter >",  onclick = "geheVor()")
  ),

  # Hamburger-Menü (LINKS statt rechts)
  div(
    id = "mySidenav", class = "sidenav",
    tags$a(
      href     = "javascript:void(0)",
      class    = "closebtn",
      onclick  = "closeNav()",
      HTML("&times;")
    ),
    tags$a("Start",            onclick="zeigeAktiveSektion(0); closeNav();"),
    tags$a("Einführung",       onclick="zeigeAktiveSektion(1); closeNav();"),
    tags$a("Adenauer OS",      onclick="zeigeAktiveSektion(2); closeNav();"),
    tags$a("Fahndung",         onclick="zeigeAktiveSektion(3); closeNav();"),
    tags$a("Metadaten",        onclick="zeigeAktiveSektion(4); closeNav();"),
    tags$a("Zeitreihen",       onclick="zeigeAktiveSektion(5); closeNav();"),
    tags$a("Statistiktok",     onclick="zeigeAktiveSektion(6); closeNav();"),
    tags$a("Hashtag",          onclick="zeigeAktiveSektion(7); closeNav();"),
    tags$a("Contentschleuder", onclick="zeigeAktiveSektion(8); closeNav();"),
    tags$a("Photo-Archiv",     onclick="zeigeAktiveSektion(9); closeNav();"),
    tags$a("Video-Archiv",     onclick="zeigeAktiveSektion(10); closeNav();"),
    tags$a("Beweisführung",    onclick="zeigeAktiveSektion(11); closeNav();"),
    tags$a("Anheuern",         onclick="zeigeAktiveSektion(12); closeNav();"),
    tags$a("Impressum",        onclick="zeigeAktiveSektion(13); closeNav();")
  ),

  # --- 14 Sektionen ---

  # 1) Start
  div(
    id = "section_start", class = "sectionBlock",
    div(
      class = "sectionContent",
      p("Projekt Tricktok: Methode zur systematischen Erfassung, Dokumentation und Analyse von Medien auf Tiktok."),
      img(
        src   = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/adenauer-os/static/banderole.png",
        style = "width:100%; max-width:900px; height:auto; margin-top:10px;"
      )
    )
  ),

  # 2) Einführung
  div(
    id = "section_intro", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "markdown-container",
        includeMarkdown("intro.md")
      )
    )
  ),

  # 3) Adenauer OS
  div(
    id = "section_adenaueros", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://tricktok.afd-verbot.de/")
      )
    )
  ),

  # 4) Fahndungsliste
  div(
    id = "section_fahndung", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://tricktok.afd-verbot.de/fahndungsliste")
      )
    )
  ),

  # 5) Metadaten
  div(
    id = "section_meta", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "meta-info-block",
        img(
          src    = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-remote-beobachter/qrcode.png",
          height = "200px"
        ),
        div(
          class = "meta-info-text",
          p("Zentrale Datenbank verwaltet Tiktok-Kanäle der Fahndungsliste und stellt Links für automatisierten Abruf bereit. Mehrere Clients nutzen verteilte Verbindungen, um Anfragen an Tiktok-Server zu senden. Erhaltene Metadaten und Reichweitenstatistiken werden in zentraler Datenbank gespeichert. Ein Python-Programm übernimmt Extraktion der Daten. Verteilter Abruf auf mehreren Geräten reduziert das Risiko von IP-Sperrungen. Live-Monitoring ermöglicht kontinuierliche Reichweiten-Erfassung.")
        )
      ),
      div(
        class = "exportButtons",
        downloadButton("download_links",      "Export Fahndungsliste"),
        downloadButton("download_metadata",   "Export Medien-Metadaten"),
        downloadButton("download_timeseries", "Export Zeitreihen")
      )
    )
  ),

  # 6) Zeitreihen
  div(
    id = "section_zeitreihen", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/zeitreihen/?uploader=23.02.25afd&video=7471398852642278678")
      )
    )
  ),

  # 7) Statistiktok
  div(
    id = "section_iframeExtra", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/statistiktok/")
      )
    )
  ),

  # 8) Hashtag
  div(
    id = "section_hashtag", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://tricktok.afd-verbot.de/suche/")
      )
    )
  ),

  # 9) Contentschleuder
  div(
    id = "section_medienholen", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/bilderwerfer/")
      )
    )
  ),

  # 10) Photo-Archiv
  div(
    id = "section_photoarchiv", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/photoarchiv/")
      )
    )
  ),

  # 11) Video-Archiv
  div(
    id = "section_videoarchiv", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://tricktok.afd-verbot.de/video_feature")
      )
    )
  ),

  # 12) Beweisführung
  div(
    id = "section_reiter2", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/beweise/")
      )
    )
  ),

  # 13) Anheuern
  div(
    id = "section_anheuern", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "markdown-container",
        includeMarkdown("anheuern.md")
      )
    )
  ),

  # 14) Impressum
  div(
    id = "section_impressum", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "markdown-container",
        includeMarkdown("impressum.md")
      )
    )
  )
)

# -------------------------------------------------------
# Server-Logik
# -------------------------------------------------------
server <- function(input, output, session) {
  cat("[Server] Appstart. Verbindung zur DB...\n")

  # DB-Verbindung
  dotenv::load_dot_env(".env")
  con <- dbConnect(
    Postgres(),
    dbname   = Sys.getenv("DB_NAME"),
    host     = Sys.getenv("DB_HOST"),
    port     = as.integer(Sys.getenv("DB_PORT")),
    user     = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASS")
  )
  onSessionEnded(function() {
    cat("[Server] Session beendet -> DB-Verbindung trennen\n")
    dbDisconnect(con)
  })

  # Gemeinsamer 30s-Cooldown
  observe({})

  checkCooldown <- function() {
    nowSec <- as.numeric(Sys.time())
    diff   <- nowSec - LAST_DOWNLOAD_TIME
    if(diff < COOLDOWN_SECONDS) {
      stop(paste0(
        "Bitte noch ",
        round(COOLDOWN_SECONDS - diff),
        " Sekunden warten, bevor erneut exportiert wird!"
      ))
    }
    assign("LAST_DOWNLOAD_TIME", nowSec, envir = .GlobalEnv)
  }

  output$download_links <- downloadHandler(
    filename = function() {
      paste0("links_", Sys.Date(), ".csv")
    },
    content = function(file) {
      checkCooldown()
      df <- lade_links(con)
      write.csv(df, file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )

  output$download_metadata <- downloadHandler(
    filename = function() {
      paste0("media_metadata_", Sys.Date(), ".csv")
    },
    content = function(file) {
      checkCooldown()
      df <- lade_media_metadata(con)
      write.csv(df, file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )

  output$download_timeseries <- downloadHandler(
    filename = function() {
      paste0("media_time_series_", Sys.Date(), ".csv")
    },
    content = function(file) {
      checkCooldown()
      df <- lade_media_time_series(con)
      write.csv(df, file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )
}

cat("==== Starting shinyApp ====\n")

shinyApp(
  ui = ui,
  server = server,
  options = list(
    host           = "0.0.0.0",
    port           = 4040,
    launch.browser = FALSE
  )
)
