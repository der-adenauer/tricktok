#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# ==================================================================
# Shiny-App mit pagePiling und 11 Sektionen
# Optimiert für mobile Endgeräte: Vollflächige iFrames, Hamburger-Menü,
# reduzierter Rand, kein Scroll-Overflow
# Keine Personalpronomen in Kommentaren und Texten
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
# Hilfsfunktion: Lädt Metadaten aus PostgreSQL
# -------------------------------------------------------
lade_tricktok_daten <- function(con) {
  abfrage <- "
    SELECT
      id, title, duration, view_count, like_count,
      uploader, timestamp
    FROM media_metadata
    ORDER BY id DESC
  "
  df <- dbGetQuery(con, abfrage)
  cat("[lade_tricktok_daten] Zeilenanzahl:", nrow(df), "\n")

  if ("timestamp" %in% names(df)) {
    df$timestamp <- as.numeric(df$timestamp)
    df$datetime  <- as.POSIXct(df$timestamp, origin = "1970-01-01", tz = "UTC")
  }

  df
}

# -------------------------------------------------------
# Benutzeroberfläche
# -------------------------------------------------------
ui <- fluidPage(
  style = "margin:0; padding:0;",

  tags$head(
    # Meta-Viewport für mobiles Skalieren
    tags$meta(name = "viewport", content = "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"),

    # JavaScript-Methoden für Button-Navigation (pagePiling)
    tags$script(
      HTML("
        Shiny.addCustomMessageHandler('pp_moveUp', function(message) {
          $.fn.pagepiling.moveSectionUp();
        });
        Shiny.addCustomMessageHandler('pp_moveDown', function(message) {
          $.fn.pagepiling.moveSectionDown();
        });

        // Öffnen/Schließen des Hamburger-Menüs
        function openNav() {
          document.getElementById('mySidenav').style.width = '200px';
        }
        function closeNav() {
          document.getElementById('mySidenav').style.width = '0';
        }
      ")
    ),

    # CSS-Anpassungen
    tags$style(HTML("
      html, body {
        margin: 0;
        padding: 0;
        overflow: hidden; /* pagePiling steuert Scrollen */
        background-color: #ffffff;
      }

      /* Verhindert Navigationskreise (Bullets) */
      .pp-slidesNav, .pp-nav {
        display: none !important;
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
        right: 0px;
        font-size: 40px;
        margin-left: 50px;
        text-decoration: none;
      }

      /* Bereich am unteren Rand freilassen (60px) */
      .pp-section {
        padding-bottom: 60px !important; /* freier Bereich unten */
      }

      /* Buttons unten rechts (< und >) */
      #bottomNav {
        position: fixed;
        bottom: 10px;
        right: 10px;
        display: flex;
        flex-direction: column;
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

      /* Vollflächige iFrames, an Gerät anpassen */
      .iframe-wrapper {
        width: 100%;
        min-height: calc(100vh - 60px);
        display: flex;
        justify-content: center;
        align-items: center;
        overflow: hidden;
      }
      .iframe-wrapper iframe {
        width: 100%;
        height: auto;
        border: none;
        display: block;
      }

      /* Seite 1: Logo, Titel, Text zentriert */
      #logo_projekt img {
        max-width: 40%;
        height: auto;
        filter: invert(1);
      }
      .projektTitel {
        font-size: 24px;
        font-weight: bold;
        color: white;
        margin: 10px 0 5px 0;
      }

      /* Markdown-Container */
      .markdown-container {
        max-width: 800px;
        margin: auto;
        padding: 20px;
      }

      /* Kleinere Tabelle zur Anzeige der letzten drei Datensätze */
      .miniTable {
        margin: auto;
        width: 90%;
        border-collapse: collapse;
      }
      .miniTable th, .miniTable td {
        border: 1px solid #ccc;
        padding: 5px;
      }
      .miniTable th {
        background: #eee;
      }
    "))
  ),

  # Hamburger-Menü-Button
  tags$button(
    id = "hamburgerBtn",
    HTML("&#9776;"),  # Unicode für Hamburger-Icon
    onclick = "openNav()"
  ),

  # Sidebar mit Links
  div(
    id = "mySidenav",
    class = "sidenav",
    a(href = "javascript:void(0)", class = "closebtn", onclick = "closeNav()", HTML("&times;")),
    a(href = "#section_start",       "Start"),
    a(href = "#section_intro",       "Einführung"),
    a(href = "#section_adenaueros",  "Adenauer OS"),
    a(href = "#section_fahndung",    "Fahndung"),
    a(href = "#section_meta",        "Metadaten"),
    a(href = "#section_iframeExtra", "Statistiktok"),
    a(href = "#section_hashtag",     "Hashtag"),
    a(href = "#section_medienholen", "Contentschleuder"),
    a(href = "#section_photoarchiv", "Photo-Archiv"),
    a(href = "#section_videoarchiv", "Video-Archiv"),
    a(href = "#section_reiter2",     "Reiter2")
  ),

  # Haupt-Seiten mit pagePiling
  pagePiling(
    scrollOverflow = TRUE,
    navigation = FALSE,
    sections.color = c(
      "#333333", # (1) Start
      "#ffffff", # (2) Einführung
      "#cccccc", # (3) Adenauer OS
      "#cccccc", # (4) Fahndungsliste
      "#ffffff", # (5) Metadaten
      "#ffffff", # (6) Statistiktok
      "#ffffff", # (7) Hashtag-Suche
      "#cccccc", # (8) Contentschleuder
      "#ffffff", # (9) Photo-Archiv
      "#ffffff", # (10) Video-Archiv
      "#ffffff"  # (11) Reiter2
    ),
    anchors = c(
      "section_start",
      "section_intro",
      "section_adenaueros",
      "section_fahndung",
      "section_meta",
      "section_iframeExtra",
      "section_hashtag",
      "section_medienholen",
      "section_photoarchiv",
      "section_videoarchiv",
      "section_reiter2"
    ),

    # --- 1) Start ---
    pageSection(
      center = TRUE,
      menu   = "section_start",
      div(
        style = "display:flex; flex-direction:column; align-items:center; justify-content:center; height:calc(100vh - 60px);",
        id = "logo_projekt",
        img(src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg"),
        h2("Projekt Tricktok", class = "projektTitel"),
        div(
          style = "color:white; font-size:16px; max-width:600px; text-align:center; margin:auto;",
          "Methode zur systematischen Erfassung, Erhaltung und Bewertung von Medien auf Tiktok."
        )
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
      )
    ),

    # --- 3) Adenauer OS ---
    pageSection(
      center = FALSE,
      menu   = "section_adenaueros",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://tricktok.afd-verbot.de/")
        )
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
      )
    ),

    # --- 5) Metadaten ---
    pageSection(
      center = FALSE,
      menu   = "section_meta",
      fluidPage(
        style = "margin:0; padding:0;",
        h3("Tricktok-Metadatenerfassung", style="text-align:center; margin-top:10px;"),
        div(
          style = "width:80%; margin:auto; margin-bottom:20px;",
          p("
Zentrale Datenbank verwaltet Tiktok-Kanäle und stellt Links für automatisierten Abruf bereit. Ergebnisse
werden zentral gespeichert. Ein Pythonprogramm extrahiert Metadaten mit yt-dlp. 
Hohe Verteilungsdichte verhindert IP-Sperren. 
Schreibzugriff kann per E-Mail beantragt werden.
          ")
        ),

        # Letzte drei Einträge
        h4("Letzte drei Einträge in der Datenbank", style = "text-align:center;"),
        tableOutput("meta_last3"),
        br(),
        # Download-Button für gesamten Export
        div(
          style = "text-align:center;",
          downloadButton("download_all", "Export Gesamte Metadaten")
        ),
        br()
      )
    ),

    # --- 6) Statistiktok ---
    pageSection(
      center = FALSE,
      menu   = "section_iframeExtra",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://py.afd-verbot.de/statistiktok/")
        )
      )
    ),

    # --- 7) Hashtag-Suche ---
    pageSection(
      center = FALSE,
      menu   = "section_hashtag",
      fluidPage(
        style = "margin:0; padding:0;",
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://tricktok.afd-verbot.de/suche/")
        )
      )
    ),

    # --- 8) Contentschleuder ---
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
      )
    ),

    # --- 9) Photo-Archiv ---
    pageSection(
      center = FALSE,
      menu   = "section_photoarchiv",
      fluidPage(
        style = "margin:0; padding:0;",
        h3("Photo-Archiv", style="text-align:center; margin-top:10px;"),
        div(
          class = "iframe-wrapper",
          tags$iframe(src = "https://tricktok.afd-verbot.de/gallery_feature")
        )
      )
    ),

    # --- 10) Video-Archiv ---
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
      )
    ),

    # --- 11) Reiter2 ---
    pageSection(
      center = FALSE,
      menu   = "section_reiter2",
      fluidPage(
        style = "margin:0; padding:0;",
        h3("Reiter2", style="text-align:center; margin-top:10px;"),
        fluidRow("Inhalt Reiter 2")
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
  cat("[Server] Starte App. Verbinde zur DB...\n")
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
    cat("[Server] Session beendet -> DB trennen\n")
    dbDisconnect(con)
  })

  # Vollständige Metadaten laden
  alle_daten <- reactive({
    lade_tricktok_daten(con)
  })

  # Letzte 3 Einträge ermitteln
  drei_daten <- reactive({
    df <- alle_daten()
    # nur die letzten 3 Einträge
    head(df, 3)
  })

  # Ausgabe minimaler Tabelle
  output$meta_last3 <- renderTable({
    df3 <- drei_daten()
    if (nrow(df3) == 0) {
      return(data.frame(Hinweis = "Keine Einträge vorhanden"))
    }
    df3[, c("id","title","view_count","like_count","uploader","timestamp")]
  }, striped = TRUE, bordered = TRUE, spacing = "xs")

  # Download kompletter Datensatz
  output$download_all <- downloadHandler(
    filename = function() {
      paste0("tricktok_metadaten_", Sys.Date(), ".csv")
    },
    content = function(file) {
      df <- alle_daten()
      write.csv(df, file, row.names = FALSE, fileEncoding = "UTF-8")
    }
  )

  # Buttons für Seitenwechsel (pagePiling)
  observeEvent(input$prev_section, {
    session$sendCustomMessage("pp_moveUp", list())
  })
  observeEvent(input$next_section, {
    session$sendCustomMessage("pp_moveDown", list())
  })
}

# -------------------------------------------------------
# App starten
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
