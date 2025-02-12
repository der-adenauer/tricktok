#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# ==================================================================
# Shiny App mit pagePiling und 11 Seiten
# Seiten:
#   1) Start
#   2) Einführung (Markdown)
#   3) Adenauer OS (zusätzlicher Reiter)
#   4) Fahndungsliste (iFrame)
#   5) Tricktok-Metadaten
#   6) Zusatz-iFrame
#   7) Hashtag-Suche (iFrame)
#   8) Medien holen (2 Markdown nebeneinander)
#   9) Medienarchiv (2 iFrames nebeneinander)
#   10) Neuer Reiter 1
#   11) Neuer Reiter 2
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
library(DT)
library(lubridate)
library(markdown)
library(dotenv)

cat("==== START APP SCRIPT ====\n")

# -------------------------------------------------------
# Hilfsfunktion: Lade Metadaten aus PostgreSQL
# -------------------------------------------------------
load_tricktok_data <- function(con, search_term = NULL) {
  query <- "
    SELECT 
      id, title, duration, view_count, like_count,
      uploader, timestamp
    FROM media_metadata
    ORDER BY id DESC
  "
  df <- dbGetQuery(con, query)
  cat("[load_tricktok_data] Anzahl Zeilen:", nrow(df), "\n")

  if (!is.null(search_term) && nzchar(search_term)) {
    srch <- tolower(search_term)
    df <- df %>%
      filter(grepl(srch, tolower(title)))
  }

  if ("timestamp" %in% names(df)) {
    df$timestamp <- as.numeric(df$timestamp)
    df$datetime  <- as.POSIXct(df$timestamp, origin = "1970-01-01", tz = "UTC")
  }

  df
}

# -------------------------------------------------------
# UI: pagePiling mit 11 Seiten
# -------------------------------------------------------
ui <- pagePiling(
  scrollOverflow = TRUE,

  sections.color = c(
    "#333333", # 1) Start
    "#ffffff", # 2) Einführung
    "#cccccc", # 3) Adenauer OS
    "#cccccc", # 4) Fahndungsliste
    "#ffffff", # 5) Tricktok-Metadaten
    "#ffffff", # 6) Zusatz-iFrame
    "#ffffff", # 7) Hashtag-Suche
    "#cccccc", # 8) Medien holen
    "#ffffff", # 9) Medienarchiv
    "#ffffff", # 10) Neuer Reiter 1
    "#ffffff"  # 11) Neuer Reiter 2
  ),
  menu = c(
    "Start"          = "section_start",
    "Einführung"     = "section_intro",
    "Adenauer OS"    = "section_adenaueros",
    "Fahndung"       = "section_fahndung",
    "Metadaten"      = "section_meta",
    "Statistiktok"   = "section_iframeExtra",
    "Hashtag"        = "section_hashtag",
    "Medien holen"   = "section_medienholen",
    "Medienarchiv"   = "section_medienarchiv",
    "Reiter1"        = "section_reiter1",
    "Reiter2"        = "section_reiter2"
  ),
  tags$head(
    tags$style(HTML("
      .pp-section {
        padding-top: 30px !important;
      }
      #meta_table table.dataTable {
        font-size: 14px;
        width: 90%;
        margin: 0 auto;
      }
    "))
  ),

  # --- Seite 1: Start ---
  pageSection(
    center = TRUE,
    menu   = "section_start",

    div(
      style = "text-align: center; margin-bottom: 20px;",
      img(
        src   = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg",
        width = "800px", height = "auto",
        style = "filter: invert(1);"
      )
    ),

    h1("Projekt Tricktok", style = "font-size:50px; font-weight:bold; color:white; text-align:center;"),
    br(),
    div(
      style = "color:white; font-size:18px; max-width:600px; text-align:center; margin:auto;",
      "Methode zur systematischen Erfassung, Erhaltung und Bewertung von Medien auf Tiktok."
    )
  ),

  # --- Seite 2: Einführung (Markdown) ---
  pageSection(
    center = FALSE,
    menu   = "section_intro",
    fluidPage(
      style = "max-width: 800px; margin: auto;",
      includeMarkdown("intro.md")
    )
  ),

  # --- Seite 3: Adenauer OS (zusätzlicher Reiter) ---
  pageSection(
    center = FALSE,
    menu   = "section_adenaueros",
    fluidPage(
      div(
        style = "display: flex; justify-content: center; align-items: center; height: 100vh;",
        div(
          style = "transform: scale(0.8); transform-origin: center; width: 100%; display: flex; justify-content: center;",
          tags$iframe(
            src   = "https://tricktok.afd-verbot.de/",
            style = "width:100%; height:900px; border:none;"
          )
        )
      )
    )
  ),

  # --- Seite 4: Fahndungsliste (iFrame) ---
  pageSection(
    center = FALSE,
    menu   = "section_fahndung",
    fluidPage(
      div(
        style = "display: flex; justify-content: center; align-items: center; height: 100vh;",
        div(
          style = "transform: scale(0.8); transform-origin: center; width: 100%; display: flex; justify-content: center;",
          tags$iframe(
            src   = "https://tricktok.afd-verbot.de/fahndungsliste",
            style = "width:100%; height:900px; border:none;"
          )
        )
      )
    )
  ),

  # --- Seite 5: Tricktok-Metadaten ---
  pageSection(
    center = FALSE,
    menu   = "section_meta",
    h1("Tricktok-Metadatenerfassung", style = "text-align: center; font-size:30px; font-weight:bold;"),
    fluidPage(
      div(
        style = "display: flex; align-items: center; text-align: justify; gap: 20px; width: 60%; margin: auto;",

        img(
          src    = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-remote-beobachter/qrcode.png",
          height = "200px",
          style  = "flex-shrink: 0;"
        ),

        div(
          style = "flex-grow: 1; text-align: justify;",
          p("
Zentrale Datenbank verwaltet Tiktok-Kanäle der Fahndungsliste und stellt Links für automatisierten Abruf für hohe Anzahl an Clients bereit. Clients nutzen eigene Internetverbindungen, um massenhaft Anfragen an Tiktok-Server zu stellen. Erhaltene Metadaten und Reichweitenstatistiken werden anschließend zurück in zentrale Datenbank gespeist. Ein Pythonprogramm muss dafür auf Endgeräten ausgeführt werden. Programm ruft Links aus Datenbank ab, extrahiert Metadaten mit python-Modul yt-dlp und speichert Ergebnisse in Datenbank. Verteilter Abruf auf mehreren Geräten verhindert IP-Sperren. Wenn viele Geräte in periodischen Intervallen Metadaten sammeln, entsteht Live-Monitoring beliebiger Kanäle bezüglich Reichweiten täglicher Veröffentlichungen.

Schreibzugriff auf Tricktok-Datenbank ist nicht möglich und muss per Anfrage an adenauer@tutamail.com angefordert werden.
          ")
        )
      ),

      br(),
      div(
        style = "text-align: center; margin-top: 20px;",
        # Falls eine Suchbox gewünscht: textInput("meta_search", "Suchbegriff (Title):", "")
      ),
      br(),
      textOutput("meta_info"),
      DTOutput("meta_table")
    )
  ),

  # --- Seite 6: Zusatz-iFrame ---
  pageSection(
    center = FALSE,
    menu   = "section_iframeExtra",
    fluidPage(
      tags$iframe(
        src   = "https://py.afd-verbot.de/statistiktok/",
        style = "width:100%; height:700px; border:none;"
      )
    )
  ),

  # --- Seite 7: Hashtag-Suche (iFrame) ---
  pageSection(
    center = FALSE,
    menu   = "section_hashtag",
    fluidPage(
      tags$iframe(
        src   = "https://tricktok.afd-verbot.de/suche/",
        style = "width:100%; height:800px; border:none;"
      )
    )
  ),

  # --- Seite 8: Medien holen (2 Markdown nebeneinander) ---
  pageSection(
    center = FALSE,
    menu   = "section_medienholen",
    fluidPage(
      fluidRow(
        column(6, includeMarkdown("links.md")),
        column(6, includeMarkdown("rechts.md"))
      )
    )
  ),

  # --- Seite 9: Medienarchiv (2 iFrames nebeneinander) ---
  pageSection(
    center = FALSE,
    menu   = "section_medienarchiv",
    fluidPage(
      fluidRow(
        column(6,
          tags$iframe(
            src   = "https://tricktok.afd-verbot.de/gallery_feature",
            style = "width:100%; height:800px; border:none;"
          )
        ),
        column(6,
          tags$iframe(
            src   = "https://tricktok.afd-verbot.de/video_feature",
            style = "width:100%; height:800px; border:none;"
          )
        )
      )
    )
  ),

  # --- Seite 10: Neuer Reiter 1 ---
  pageSection(
    center = FALSE,
    menu   = "section_reiter1",
    h1("Neuer Reiter 1", style = "font-size:30px; font-weight:bold;"),
    fluidPage(
      fluidRow("Inhalt Reiter 1")
    )
  ),

  # --- Seite 11: Neuer Reiter 2 ---
  pageSection(
    center = FALSE,
    menu   = "section_reiter2",
    h1("Neuer Reiter 2", style = "font-size:30px; font-weight:bold;"),
    fluidPage(
      fluidRow("Inhalt Reiter 2")
    )
  )
)

# -------------------------------------------------------
# Server
# -------------------------------------------------------
server <- function(input, output, session) {
  cat("[Server] Starte... Verbinde zur PostgreSQL...\n")
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
    cat("[Server] Session end -> DB disconnect\n")
    dbDisconnect(con)
  })

  tricktok_df <- reactive({
    load_tricktok_data(con, search_term = input$meta_search)
  })

  output$meta_info <- renderText({
    df <- tricktok_df()
    paste("Gesamtzahl (nach Filter):", nrow(df))
  })

  output$meta_table <- DT::renderDataTable({
    df <- tricktok_df()
    DT::datatable(
      df,
      options = list(
        pageLength = 5,
        lengthMenu = list(c(5, 15, -1), c('5', '15', 'Alle')),
        searching  = FALSE
      )
    )
  })
}

# -------------------------------------------------------
# Start ShinyApp
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
