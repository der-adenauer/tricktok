#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# ==============================================================
# Shiny App mit pagePiling und 8 Seiten
# Seiten:
#   1) Start
#   2) Einführung (Markdown)
#   3) Fahndungsliste (iFrame)
#   4) Tricktok-Metadaten
#   5) Zusatz-iFrame (neu nach Metadaten)
#   6) Hashtag-Suche (iFrame)
#   7) Medien holen (2 Markdown nebeneinander)
#   8) Medienarchiv (2 iFrames nebeneinander)
# ==============================================================

# Mehr Logging & Debug in Shiny:
options(shiny.fullstacktrace = TRUE)
options(shiny.error = traceback)
options(shiny.sanitize.errors = FALSE)
options(shiny.trace = TRUE)
options(shiny.reactlog = TRUE)

library(shiny)
library(fullPage)    # Für pagePiling
library(DBI)
library(RPostgres)   # PostgreSQL
library(dplyr)
library(DT)
library(lubridate)
library(markdown)

cat("==== START APP SCRIPT ====\n")

# -------------------------------------------------------
# 1) Hilfsfunktion: Lade Metadaten aus PostgreSQL
# -------------------------------------------------------
load_tricktok_data <- function(con, search_term=NULL){
  query <- "
    SELECT 
      id, title, duration, view_count, like_count,
      uploader, timestamp
    FROM media_metadata
    ORDER BY id DESC
  "
  df <- dbGetQuery(con, query)
  cat("[load_tricktok_data] Anzahl Zeilen:", nrow(df), "\n")

  # Optional: Suchfilter (nur im title)
  if(!is.null(search_term) && nzchar(search_term)){
    srch <- tolower(search_term)
    df <- df %>%
      filter(grepl(srch, tolower(title)))
  }

  # Timestamp als numeric => POSIXct
  if("timestamp" %in% names(df)){
    df$timestamp <- as.numeric(df$timestamp)
    df$datetime  <- as.POSIXct(df$timestamp, origin="1970-01-01", tz="UTC")
  }

  df
}

# -------------------------------------------------------
# 2) UI: pagePiling mit 8 Seiten
# -------------------------------------------------------
ui <- pagePiling(
  sections.color = c(
    "#444444", "#fefefe", "#cccccc",
    "#d0d0d0", "#f4f4f4", "#b0b0b0",
    "#e8e8e8", "#fafafa"
  ),
  menu = c(
    "Start"          = "section_start",
    "Einführung"     = "section_intro",
    "Fahndung"       = "section_fahndung",
    "Metadaten"      = "section_meta",
    "Zusatz-iFrame"  = "section_iframeExtra",
    "Hashtag"        = "section_hashtag",
    "Medien holen"   = "section_medienholen",
    "Medienarchiv"   = "section_medienarchiv"
  ),
  # Damit kein Scrollen notwendig ist:
  tags$head(
    tags$style(HTML("
      .pp-section {
        padding-top: 30px !important;
      }
      /* Kleineres DT-Layout */
      #meta_table table.dataTable {
        font-size: 14px;
        width: 90%;
        margin: 0 auto;
      }
      /* Evtl. minimaler margin-bottom, falls gewünscht */
    "))
  ),

  # --- Seite 1: Start / Deckblatt ---
  pageSection(
    center = TRUE,
    menu   = "section_start",
    h1("Tricktok", style="font-size:50px; font-weight:bold; color:white;"),
    h2("Analysen", style="color:white;"),
    br(),
    div(
      style="color:white; font-size:18px; max-width:600px;",
      " Tricktok - systematische Erfassung, Erhaltung und Bewertung von Medien auf Tiktok ."
    )
  ),

  # --- Seite 2: Einführung (Markdown) ---
  pageSection(
    center = FALSE,
    menu   = "section_intro",
    h1("Einführung", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      # Pfad anpassen:
      includeMarkdown("intro.md")

    )
  ),

  # --- Seite 3: Fahndungsliste (iFrame) ---
  pageSection(
    center = FALSE,
    menu   = "section_fahndung",
#    h1("Fahndungsliste", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      tags$iframe(
        src   = "https://tricktok.afd-verbot.de/fahndungsliste",
        style = "width:100%; height:800px; border:none;"
      )
    )
  ),

  # --- Seite 4: Tricktok-Metadaten ---
  pageSection(
    center = FALSE,
    menu   = "section_meta",
    h1("Tricktok-Metadaten", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      fluidRow(
        column(4,
          textInput("meta_search", "Suchbegriff (Title):", "")
        )
      ),
      br(),
      textOutput("meta_info"),
      DTOutput("meta_table")
    )
  ),

  # --- Seite 5: Zusatz-iFrame (neu nach Metadaten) ---
  pageSection(
    center = FALSE,
    menu   = "section_iframeExtra",
    h1("Zusätzliche iFrame-Seite", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      tags$iframe(
        src   = "https://py.afd-verbot.de/statistiktok/",
        style = "width:100%; height:700px; border:none;"
      )
    )
  ),

  # --- Seite 6: Hashtag-Suche (iFrame) ---
  pageSection(
    center = FALSE,
    menu   = "section_hashtag",
    h1("Hashtag-Suche", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      tags$iframe(
        src   = "https://tricktok.afd-verbot.de/suche/",
        style = "width:100%; height:800px; border:none;"
      )
    )
  ),

  # --- Seite 7: Medien holen (2 Markdown nebeneinander) ---
  pageSection(
    center = FALSE,
    menu   = "section_medienholen",
    h1("Medien holen", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      fluidRow(
        column(6, includeMarkdown("links.md")),
        column(6, includeMarkdown("rechts.md"))
      )
    )
  ),

  # --- Seite 8: Medienarchiv (2 iFrames nebeneinander) ---
  pageSection(
    center = FALSE,
    menu   = "section_medienarchiv",
    h1("Medienarchiv", style="font-size:30px; font-weight:bold;"),
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
  )
)

# -------------------------------------------------------
# 3) Server
# -------------------------------------------------------
server <- function(input, output, session){
  cat("[Server] Starte... Verbinde zur PostgreSQL...\n")
  con <- dbConnect(
    RPostgres::Postgres(),
    dbname   = Sys.getenv("DB_NAME", "tiktokdb"),
    host     = Sys.getenv("DB_HOST", "188.245.249.154"),
    port     = as.integer(Sys.getenv("DB_PORT", "5432")),
    user     = Sys.getenv("DB_USER", "tiktok_writer"),
    password = Sys.getenv("DB_PASS", "Wr!T3r_92@kLm")
  )
  onSessionEnded(function(){
    cat("[Server] Session end -> DB disconnect\n")
    dbDisconnect(con)
  })

  # (A) Metadaten: reaktives Laden + Filter
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
      # Angelehnt an DT-Beispiele:
      options = list(
        pageLength = 5,  # pro Seite 5 Einträge
        lengthMenu = list(c(5, 15, -1), c('5', '15', 'All')),
        searching  = FALSE  # keine Suchbox
      )
    )
  })
}

# -------------------------------------------------------
# 4) Start ShinyApp
# -------------------------------------------------------
cat("==== Starting shinyApp ====\n")
shinyApp(
  ui     = ui,
  server = server,
  options= list(
    host           = "0.0.0.0",
    port           = 4040,
    launch.browser = FALSE
  )
)
