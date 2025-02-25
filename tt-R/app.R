#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# ==================================================
# Shiny-App mit:
#   - Endlos-Scroll, 14 Abschnitte
#   - CSS-Scroll-Snap (snapt zu jedem Abschnitt)
#   - Hamburger-Menü links oben
#   - Sticky-Logo + Reload-Icon oben rechts
#   - IFrames in 100% Größe (an Viewport angepasst)
#   - CSV-Download-Handler für DB
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
  # Kein Standard-Padding/Margin
  style = "margin:0; padding:0;",

  tags$head(
    # Responsives Meta-Viewport
    tags$meta(name="viewport", content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"),

    # JavaScript für Hamburger-Menü
    tags$script(HTML("
      function openNav(){
        document.getElementById('mySidenav').style.width = '250px';
      }
      function closeNav(){
        document.getElementById('mySidenav').style.width = '0';
      }
      document.addEventListener('click', function(e){
        var sidenav = document.getElementById('mySidenav');
        var hamburgerBtn = document.getElementById('hamburgerBtn');
        if(!sidenav.contains(e.target) && !hamburgerBtn.contains(e.target)){
          closeNav();
        }
      });
    ")),

    # CSS für Scroll-Snap, Layout usw.
    tags$style(HTML("
      /* Grundlayout: vertikales Scrollen mit snap */
      html, body {
        margin: 0;
        padding: 0;
        height: 100%;
        scroll-snap-type: y mandatory; /* Hauptmerkmal: Snap in Y-Richtung */
        overflow-y: scroll;
        overflow-x: hidden;
        font-family: sans-serif;
        background-color: #fff;
      }
      /* Jede Sektion snappt an den Start */
      .sectionBlock {
        scroll-snap-align: start;
        position: relative;
        width: 100%;
        height: 100vh; /* Jede Sektion füllt genau eine Bildschirmhöhe */
      }

      /* Hamburger-Button links oben */
      #hamburgerBtn {
        position: fixed;
        top: 10px;
        left: 10px;
        z-index: 10001;
        background-color: transparent;
        border: none;
        font-size: 30px;
        cursor: pointer;
        color: #000;
      }

      /* Sidebar/Hamburger-Menü */
      .sidenav {
        height: 100%;
        width: 0;
        position: fixed;
        z-index: 10000;
        top: 0;
        left: 0;
        background-color: rgba(255,255,255,0.95);
        overflow-x: hidden;
        transition: 0.3s;
        padding-top: 60px;
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
        right: 10px;
        font-size: 40px;
      }

      /* Sticky-Container oben rechts, enthält Logo und Reload-Icon */
      .topRightSticky {
        position: fixed;
        top: 10px;
        right: 10px;
        z-index: 10002;
        display: flex;
        align-items: center;
        gap: 15px;
      }
      /* Logo */
      #logoImage {
        width: 100px;
        height: auto;
      }
      /* Reload-Icon: Kreis mit Pfeil, rotiert beim Hover */
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

      /* IFrame-Wrapper: füllt komplette Section minus evtl. Überschriften */
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

      /* Beispiel-Farbhintergründe wie gewünscht */
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

      /* Optionale Headline & Text-Styles in den Sections */
      .sectionContent {
        padding: 20px;
        max-width: 800px;
        margin: 0 auto;
      }
      h2.sectionHeadline {
        margin-top: 20px;
        font-size: 32px;
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

      /* Mobile Adjustments */
      @media (max-width: 768px){
        #logoImage {
          width: 80px;
        }
        .reloadIcon {
          width: 35px;
          height: 35px;
          font-size: 18px;
        }
      }
    "))
  ),

  # Hamburger-Menü-Button
  tags$button(
    id = "hamburgerBtn",
    HTML("&#9776;"),
    onclick = "openNav()"
  ),

  # Sticky-Bereich oben rechts: Logo + Reload
  div(
    class="topRightSticky",
    tags$img(
      id="logoImage",
      src="https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg"
    ),
    div(
      class="reloadIcon",
      HTML("&#x21bb;"),  # kreisender Pfeil
      onclick="location.reload();"
    )
  ),

  # Seitliche Navigation (Hamburger-Menü)
  div(
    id="mySidenav", class="sidenav",
    tags$a(href="javascript:void(0)", class="closebtn", onclick="closeNav()", HTML("&times;")),

    tags$a(href="#section_start",       "Start"),
    tags$a(href="#section_intro",       "Einführung"),
    tags$a(href="#section_adenaueros",  "Adenauer OS"),
    tags$a(href="#section_fahndung",    "Fahndung"),
    tags$a(href="#section_meta",        "Metadaten"),
    tags$a(href="#section_zeitreihen",  "Zeitreihen"),
    tags$a(href="#section_iframeExtra", "Statistiktok"),
    tags$a(href="#section_hashtag",     "Hashtag"),
    tags$a(href="#section_medienholen", "Contentschleuder"),
    tags$a(href="#section_photoarchiv", "Photo-Archiv"),
    tags$a(href="#section_videoarchiv", "Video-Archiv"),
    tags$a(href="#section_reiter2",     "Beweisführung"),
    tags$a(href="#section_anheuern",    "Anheuern"),
    tags$a(href="#section_impressum",   "Impressum")
  ),

  # 14 Sektionen, je 100vh hoch, scroll-snap
  # 1) Start
  div(
    id="section_start", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Projekt Tricktok", class="sectionHeadline"),
      p("Methode zur systematischen Erfassung, Dokumentation und Analyse von Medien auf Tiktok."),
      img(
        src="https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/adenauer-os/static/banderole.png",
        style="width:100%; max-width:900px; height:auto; margin-top:10px;"
      )
    )
  ),

  # 2) Einführung
  div(
    id="section_intro", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Einführung", class="sectionHeadline"),
      div(
        class="markdown-container",
        includeMarkdown("intro.md")
      )
    )
  ),

  # 3) Adenauer OS
  div(
    id="section_adenaueros", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Adenauer OS", class="sectionHeadline")
    ),
    div(
      class="iframe-wrapper",
      # Leicht skaliert
      tags$iframe(
        src="https://tricktok.afd-verbot.de/",
        style="transform:scale(0.8); transform-origin: top center; width:125%; height:125%;"
      )
    )
  ),

  # 4) Fahndungsliste
  div(
    id="section_fahndung", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Fahndungsliste", class="sectionHeadline")
    ),
    div(
      class="iframe-wrapper",
      tags$iframe(src="https://tricktok.afd-verbot.de/fahndungsliste")
    )
  ),

  # 5) Metadaten
  div(
    id="section_meta", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Tricktok Metadaten", class="sectionHeadline"),
      div(
        class="meta-info-block",
        img(
          src="https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-remote-beobachter/qrcode.png",
          height="200px"
        ),
        div(
          class="meta-info-text",
          p("Zentrale Datenbank verwaltet Tiktok-Kanäle ...")
        )
      ),
      div(
        class="exportButtons",
        downloadButton("download_links",      "Export Fahndungsliste"),
        downloadButton("download_metadata",   "Export Medien-Metadaten"),
        downloadButton("download_timeseries", "Export Zeitreihen")
      )
    )
  ),

  # 6) Zeitreihen
  div(
    id="section_zeitreihen", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Zeitreihen", class="sectionHeadline")
    ),
    div(
      class="iframe-wrapper",
      tags$iframe(src="https://py.afd-verbot.de/zeitreihen/?uploader=23.02.25afd&video=7471398852642278678")
    )
  ),

  # 7) Statistiktok
  div(
    id="section_iframeExtra", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Statistiktok", class="sectionHeadline")
    ),
    div(
      class="iframe-wrapper",
      tags$iframe(src="https://py.afd-verbot.de/statistiktok/")
    )
  ),

  # 8) Hashtag-Suche
  div(
    id="section_hashtag", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Hashtag-Suche", class="sectionHeadline")
    ),
    div(
      class="iframe-wrapper",
      tags$iframe(src="https://tricktok.afd-verbot.de/suche/")
    )
  ),

  # 9) Contentschleuder
  div(
    id="section_medienholen", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Contentschleuder", class="sectionHeadline")
    ),
    div(
      class="iframe-wrapper",
      tags$iframe(src="https://py.afd-verbot.de/bilderwerfer/")
    )
  ),

  # 10) Photo-Archiv
  div(
    id="section_photoarchiv", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Photo-Archiv", class="sectionHeadline")
    ),
    div(
      class="iframe-wrapper",
      tags$iframe(src="https://py.afd-verbot.de/photoarchiv/")
    )
  ),

  # 11) Video-Archiv
  div(
    id="section_videoarchiv", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Video-Archiv", class="sectionHeadline")
    ),
    div(
      class="iframe-wrapper",
      tags$iframe(src="https://tricktok.afd-verbot.de/video_feature")
    )
  ),

  # 12) Reiter2 / Beweisführung
  div(
    id="section_reiter2", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Beweisführung", class="sectionHeadline")
    ),
    div(
      class="iframe-wrapper",
      tags$iframe(src="https://py.afd-verbot.de/beweise/")
    )
  ),

  # 13) Anheuern
  div(
    id="section_anheuern", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Anheuern", class="sectionHeadline"),
      div(
        class="markdown-container",
        includeMarkdown("anheuern.md")
      )
    )
  ),

  # 14) Impressum
  div(
    id="section_impressum", class="sectionBlock",
    div(
      class="sectionContent",
      h2("Impressum", class="sectionHeadline"),
      div(
        class="markdown-container",
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

  # DB-Verbindung (optional)
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

  # CSV-Downloads
  output$download_links <- downloadHandler(
    filename = function() { paste0("links_", Sys.Date(), ".csv") },
    content = function(file) {
      df <- lade_links(con)
      write.csv(df, file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )
  output$download_metadata <- downloadHandler(
    filename = function() { paste0("media_metadata_", Sys.Date(), ".csv") },
    content = function(file) {
      df <- lade_media_metadata(con)
      write.csv(df, file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )
  output$download_timeseries <- downloadHandler(
    filename = function() { paste0("media_time_series_", Sys.Date(), ".csv") },
    content = function(file) {
      df <- lade_media_time_series(con)
      write.csv(df, file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )
}

# -------------------------------------------------------
# App-Start
# -------------------------------------------------------
cat("==== Starting shinyApp ====\n")
shinyApp(
  ui = ui,
  server = server,
  options = list(
    host="0.0.0.0",
    port=4040,
    launch.browser=FALSE
  )
)
