#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# ==================================================================
# Shiny-App mit pagePiling und 14 Sektionen
# Optimiert für mobile Endgeräte:
# - iFrames schließen bündig mit dem unteren Bildschirmrand ab
# - Abstandsreserve nach oben für ein wenig "Luft"
# - Hamburger-Menü, drei Tabellen-Exporte
# - Buttons Prev/Nächste nebeneinander (unten rechts)
# - Startseite mit größerer Überschrift, zusätzlichem Bild und mittiger Ausrichtung
# - Logo in invertierter Darstellung nur in der ersten Sektion
# - Im Abschnitt „Adenauer OS“ wird der Inhalt im iFrame gezoomt
# ==================================================================

options(shiny.fullstacktrace = TRUE)
options(shiny.error = traceback)
options(shiny.sanitize.errors = FALSE)
options(shiny.trace = TRUE)
options(shiny.reactlog = TRUE)

library(shiny)
library(fullPage)
library(DBI)
library(RPostgres)
library(dplyr)
library(lubridate)
library(markdown)
library(dotenv)

cat("==== START APP SCRIPT ====\n")

# -------------------------------------------------------
# Hilfsfunktionen: Lädt Datensätze aus PostgreSQL
# -------------------------------------------------------
lade_links <- function(con) {
  query <- "
    SELECT
      id, url, inserted_at, processed
    FROM links
    ORDER BY id DESC
  "
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
    # Meta-Viewport für mobile Endgeräte
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"),

    # JavaScript-Methoden für Button-Navigation (pagePiling) und Hamburger-Menü
    tags$script(
      HTML("
        Shiny.addCustomMessageHandler('pp_moveUp', function(message) {
          $.fn.pagepiling.moveSectionUp();
        });
        Shiny.addCustomMessageHandler('pp_moveDown', function(message) {
          $.fn.pagepiling.moveSectionDown();
        });

        function openNav() {
          document.getElementById('mySidenav').style.width = '250px';
        }
        function closeNav() {
          document.getElementById('mySidenav').style.width = '0';
        }

        document.addEventListener('click', function(e) {
          var sidenav = document.getElementById('mySidenav');
          var hamburgerBtn = document.getElementById('hamburgerBtn');
          if (!sidenav.contains(e.target) && !hamburgerBtn.contains(e.target)) {
            closeNav();
          }
        });
      ")
    ),

    # ------------------------------
    # Zentrales CSS
    # ------------------------------
    tags$style(HTML("
      html, body {
        margin: 0;
        padding: 0;
        overflow: hidden;
        background-color: #ffffff;
      }

      /* pagePiling entfernt standardmäßig die Navigationskreise */
      .pp-slidesNav, .pp-nav {
        display: none !important;
      }

      /* Jede Sektion bekommt die volle Bildschirmhöhe */
      .pp-section {
        position: relative;
        width: 100%;
        height: 100vh !important;
        margin: 0;
        padding: 0;
      }

      /* Hamburger-Button oben links */
      #hamburgerBtn {
        position: fixed;
        top: 0;
        left: 0;
        font-size: 30px;
        margin: 5px 10px;
        z-index: 10001;
        background-color: transparent;
        border: none;
        color: #000000;
        cursor: pointer;
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
        font-family: sans-serif;
      }
      .sidenav a {
        padding: 8px 8px 8px 16px;
        text-decoration: none;
        font-size: 18px;
        color: #000000;
        display: block;
        transition: 0.3s;
        font-weight: bold;
      }
      .sidenav a:hover {
        background-color: #ddd;
      }
      .sidenav .closebtn {
        position: absolute;
        top: 0;
        right: 10px;
        font-size: 40px;
        text-decoration: none;
      }

      /* Buttons unten rechts side-by-side (z.B. Prev/Nächste) */
      #bottomNav {
        position: fixed;
        bottom: 10px;
        right: 10px;
        display: flex;
        flex-direction: row;
        gap: 10px;
        z-index: 9999;
      }
      .navBtn {
        background-color: rgba(128,128,128,0.5);
        color: #ffffff;
        border: none;
        padding: 15px 20px;
        cursor: pointer;
        font-size: 24px;
        font-weight: bold;
        border-radius: 4px;
      }
      .navBtn:hover {
        background-color: rgba(128,128,128,0.7);
      }

      /* iFrame-Wrapper:
         Abstand zum oberen Rand und bündig zum unteren Rand */
      .iframe-wrapper {
        position: absolute;
        top: 6vh;
        bottom: 0;
        left: 0;
        right: 0;
        display: flex;
        justify-content: center;
        align-items: center;
        overflow: hidden;
      }
      .iframe-wrapper iframe {
        width: 100%;
        height: 100%;
        border: none;
        display: block;
      }

      /* Spezieller Zoom NUR für adenaueros-Abschnitt */
      section[data-anchor='section_adenaueros'] .iframe-wrapper iframe {
        transform: scale(0.8);
        transform-origin: top center;
        width: 125%;
        height: 125%;
      }

      /* Kleines Logo oben rechts (Standard ohne Filter) */
      .smallLogoContainer {
        position: absolute;
        top: 1%;
        right: 2%;
        z-index: 10002;
      }
      .smallLogoContainer img {
        width: 100px;
        height: auto;
        filter: none;
      }

      /* Inversion nur auf erster Seite (Start) */
      section[data-anchor='section_start'] .smallLogoContainer img {
        filter: invert(100%);
      }

      /* Überschrift auf Startseite (größer) */
      .projektTitel {
        font-size: 40px;
        font-weight: bold;
        color: white;
        margin: 10px 0 5px 0;
        text-align: center;
      }

      /* Markdown-Container */
      .markdown-container {
        max-width: 800px;
        margin: auto;
        padding: 20px;
      }

      /* Info-Blöcke auf Metadaten-Seite */
      .meta-info-block {
        display: flex;
        align-items: center;
        text-align: justify;
        gap: 20px;
        width: 60%;
        margin: auto;
      }
      .meta-info-block img {
        flex-shrink: 0;
      }
      .meta-info-text {
        flex-grow: 1;
      }

      /* Buttons (3 Exporte) zentriert */
      .exportButtons {
        text-align: center;
        margin: 20px 0;
      }
      .exportButtons button {
        margin: 0 10px;
      }

      /* Mobile Ansicht */
      @media (max-width: 768px) {
        .iframe-wrapper {
          top: 6vh;
        }
        section[data-anchor='section_adenaueros'] .iframe-wrapper iframe {
          transform: scale(0.7);
          transform-origin: top center;
          width: 143%;
          height: 143%;
        }
        .meta-info-block {
          flex-direction: column;
          align-items: flex-start;
          width: 90%;
        }
      }

      /* Zoom-Anpassung für kleinere Laptops */
      @media (max-width: 1366px) {
        body {
          zoom: 0.9;
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

  # Sidebar/Hamburger-Menü
  div(
    id = "mySidenav",
    class = "sidenav",
    a(href = "javascript:void(0)", class = "closebtn", onclick = "closeNav()", HTML("&times;")),
    a(href = "#section_start",       "Start"),
    a(href = "#section_intro",       "Einführung"),
    a(href = "#section_adenaueros",  "Adenauer OS"),
    a(href = "#section_fahndung",    "Fahndung"),
    a(href = "#section_meta",        "Metadaten"),
    a(href = "#section_zeitreihen",  "Zeitreihen"),
    a(href = "#section_iframeExtra", "Statistiktok"),
    a(href = "#section_hashtag",     "Hashtag"),
    a(href = "#section_medienholen", "Contentschleuder"),
    a(href = "#section_photoarchiv", "Photo-Archiv"),
    a(href = "#section_videoarchiv", "Video-Archiv"),
    a(href = "#section_reiter2",     "Beweisführung"),
    a(href = "#section_anheuern",    "Anheuern"),
    a(href = "#section_impressum",   "Impressum")
  ),

  # Haupt-Seiten mit pagePiling
  pagePiling(
    scrollOverflow = TRUE,
    navigation = FALSE,
    sections.color = c(
      "#f9ceb2",  # Start
      "#ffffff",  # Einführung
      "#cccccc",  # Adenauer OS
      "#cccccc",  # Fahndung
      "#ffffff",  # Metadaten
      "#ffffff",  # Zeitreihen
      "#ffffff",  # Statistiktok
      "#ffffff",  # Hashtag
      "#cccccc",  # Contentschleuder
      "#ffffff",  # Photo-Archiv
      "#ffffff",  # Video-Archiv
      "#ffffff",  # Reiter2
      "#ffffff",  # Anheuern
      "#ffffff"   # Impressum
    ),
    anchors = c(
      "section_start",
      "section_intro",
      "section_adenaueros",
      "section_fahndung",
      "section_meta",
      "section_zeitreihen",
      "section_iframeExtra",
      "section_hashtag",
      "section_medienholen",
      "section_photoarchiv",
      "section_videoarchiv",
      "section_reiter2",
      "section_anheuern",
      "section_impressum"
    ),

    # --- 1) Start ---
    pageSection(
      center = TRUE,
      menu   = "section_start",

      div(
        style = "
          position: relative;
          width: 100%;
          height: 100%;
          overflow: hidden;
        ",
        id = "logo_projekt",

        h3(
          "Projekt Tricktok",
          class = "projektTitel",
          style = "
            position: absolute;
            top: 25%;
            left: 50%;
            transform: translate(-50%, -50%);
            color: black;
            margin: 0;
            text-align: center;
            font-size: 42px;
          "
        ),

        div(
          style = "
            position: absolute;
            top: 30%;
            left: 50%;
            transform: translate(-50%, 0);
            color: black;
            text-align: center;
            font-size: 24px;
            max-width: 750px;
          ",
          "Methode zur systematischen Erfassung, Dokumentation und Analyse von Medien auf Tiktok."
        ),

        img(
          src = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/adenauer-os/static/banderole.png",
          style = "
            position: absolute;
            bottom: 0;
            left: 0;
            width: 100%;
            height: auto;
            display: block;
          "
        )
      ),

      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 2) Einführung ---
    pageSection(
      center = FALSE,
      menu   = "section_intro",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "markdown-container",
          includeMarkdown("intro.md")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 3) Adenauer OS (Zoom im iFrame) ---
    pageSection(
      center = FALSE,
      menu   = "section_adenaueros",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://tricktok.afd-verbot.de/")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 4) Fahndungsliste ---
    pageSection(
      center = FALSE,
      menu   = "section_fahndung",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://tricktok.afd-verbot.de/fahndungsliste")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 5) Metadaten ---
    pageSection(
      center = FALSE,
      menu   = "section_meta",
      fluidPage(
        style = "margin:0; padding:0;",
        h3("Tricktok Metadaten", style = "text-align:center; margin-top:20px;"),
        div(
          class = "meta-info-block",
          img(
            src    = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-remote-beobachter/qrcode.png",
            height = "200px"
          ),
          div(
            class = "meta-info-text",
            p("
Zentrale Datenbank verwaltet Tiktok-Kanäle der Fahndungsliste und stellt Links für automatisierten Abruf bereit. Mehrere Clients nutzen eigene Verbindungen, um massenhaft Anfragen an Tiktok-Server zu senden. Erhaltene Metadaten und Reichweitenstatistiken werden in zentraler Datenbank gespeichert. Ein Python-Programm übernimmt Extraktion der Daten. Verteilter Abruf auf mehreren Geräten verhindert das Risko von IP-Sperrungen des Systemes.
Live-Monitoring für Reichweiten beliebiger Kanäle durch regelmäßiges Sammeln von Metadaten.
            ")
          )
        ),
        div(
          class = "exportButtons",
          downloadButton("download_links",         "Export Fahndungsliste"),
          downloadButton("download_metadata",      "Export Medien-Metadaten"),
          downloadButton("download_timeseries",    "Export Zeitreihen")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 6) Zeitreihen ---
    pageSection(
      center = FALSE,
      menu   = "section_zeitreihen",
      fluidPage(
        style = "margin:0; padding:0;",
        h3("Zeitreihen", style = "text-align:center; margin-top:10px;"),
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://py.afd-verbot.de/zeitreihen/?uploader=23.02.25afd&video=7471398852642278678")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 7) Statistiktok ---
    pageSection(
      center = FALSE,
      menu   = "section_iframeExtra",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://py.afd-verbot.de/statistiktok/")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 8) Hashtag-Suche ---
    pageSection(
      center = FALSE,
      menu   = "section_hashtag",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://tricktok.afd-verbot.de/suche/")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 9) Contentschleuder ---
    pageSection(
      center = FALSE,
      menu   = "section_medienholen",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          style = "align-items:flex-end;",
          tags$iframe(src = "https://py.afd-verbot.de/bilderwerfer/")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 10) Photo-Archiv ---
    pageSection(
      center = FALSE,
      menu   = "section_photoarchiv",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://py.afd-verbot.de/photoarchiv/")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 11) Video-Archiv ---
    pageSection(
      center = FALSE,
      menu   = "section_videoarchiv",
      fluidPage(
        style = "margin:0; padding:0;",
        h3("Video-Archiv", style="text-align:center; margin-top:10px;"),
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://tricktok.afd-verbot.de/video_feature")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 12) Reiter2 (jetzt mit iFrame) ---
    pageSection(
      center = FALSE,
      menu   = "section_reiter2",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://py.afd-verbot.de/beweise/")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 13) Anheuern (Markdown) ---
    pageSection(
      center = FALSE,
      menu   = "section_anheuern",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "markdown-container",
          includeMarkdown("anheuern.md")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    ),

    # --- 14) Impressum (Markdown) ---
    pageSection(
      center = FALSE,
      menu   = "section_impressum",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "markdown-container",
          includeMarkdown("impressum.md")
        )
      ),
      div(
        class = "smallLogoContainer",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg")
      )
    )
  ),

  # Navigations-Buttons (unten rechts)
  div(
    id = "bottomNav",
    actionButton(
      inputId = "prev_section",
      label   = HTML("<span style='font-size:24px;'>&lt;</span>"),
      class   = "navBtn"
    ),
    actionButton(
      inputId = "next_section",
      label   = HTML("<span style='font-size:24px;'>&gt;</span>"),
      class   = "navBtn"
    )
  )
)

# -------------------------------------------------------
# Server
# -------------------------------------------------------
server <- function(input, output, session) {
  cat("[Server] Appstart. Verbindung zur DB...\n")

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

  # Download-Handler für CSV-Exporte
  output$download_links <- downloadHandler(
    filename = function() {
      paste0("links_", Sys.Date(), ".csv")
    },
    content = function(file) {
      df <- lade_links(con)
      write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )

  output$download_metadata <- downloadHandler(
    filename = function() {
      paste0("media_metadata_", Sys.Date(), ".csv")
    },
    content = function(file) {
      df <- lade_media_metadata(con)
      write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )

  output$download_timeseries <- downloadHandler(
    filename = function() {
      paste0("media_time_series_", Sys.Date(), ".csv")
    },
    content = function(file) {
      df <- lade_media_time_series(con)
      write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )

  # Button-Logik zum Absenden customMessages -> pagePiling
  observeEvent(input$prev_section, {
    session$sendCustomMessage("pp_moveUp", list())
  })
  observeEvent(input$next_section, {
    session$sendCustomMessage("pp_moveDown", list())
  })
}

# -------------------------------------------------------
# Start
# -------------------------------------------------------
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
