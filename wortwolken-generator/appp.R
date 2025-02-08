#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# interactive_wordcloud_app.R
# Zeigt Wortwolke für einen auswählbaren Kanal (oder alle),
# Hashtag-Umschaltung, min/max Frequenz, max. Wortanzahl, Suchfeld
# ohne req(...), stattdessen Fallbacks für Inputs.

# -----------------------------
# 1) Pakete
# -----------------------------

required_packages <- c(
  "RSQLite", "DBI", "dplyr", "tidytext", "wordcloud2",
  "stopwords", "shiny", "DT", "stringr", "shiny.fluent"
)

install_if_missing <- function(packages) {
  installed <- installed.packages()[,"Package"]
  for (pkg in packages) {
    if (!(pkg %in% installed)) {
      install.packages(pkg, dependencies = TRUE, repos = "http://cran.rstudio.com/")
    }
  }
}

install_if_missing(required_packages)

library(RSQLite)
library(DBI)
library(dplyr)
library(tidytext)
library(wordcloud2)
library(stopwords)
library(shiny)
library(DT)
library(stringr)
library(shiny.fluent)

# -----------------------------
# 2) Verbindung zur SQLite-Datenbank
# -----------------------------

DB_PATH <- "media_metadata.db"
if (!file.exists(DB_PATH)) {
  stop(paste("Datenbankdatei nicht gefunden:", DB_PATH))
}

con <- dbConnect(RSQLite::SQLite(), DB_PATH)
tables <- dbListTables(con)

if (!"media_metadata" %in% tables) {
  dbDisconnect(con)
  stop("Tabelle 'media_metadata' existiert nicht in der Datenbank.")
}

df <- dbReadTable(con, "media_metadata")
dbDisconnect(con)

if (!"title" %in% colnames(df)) {
  stop("Spalte 'title' fehlt in 'media_metadata'.")
}
df$title <- as.character(df$title)

# -----------------------------
# 3) UI
# -----------------------------

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .container-fluid {
        max-width: 1000px;
        margin: 0 auto;
        padding-left: 10px;
        padding-right: 10px;
      }
      .form-group {
        margin-bottom: 0.5rem;
      }
      table.dataTable.compact tbody td {
        padding: 4px;
      }
      .header-row .form-group {
        margin-bottom: 0;
      }
    "))
  ),

  titlePanel("Tricktok Suche"),

  fluidRow(
    class = "header-row",
    column(
      width = 2,
      selectInput(
        "uploader_select",
        "Uploader wählen:",
        choices = c("ALLE", sort(unique(df$uploader))),
        selected = "ALLE"
      )
    ),
    column(
      width = 2,
      Toggle.shinyInput(
        inputId = "hashtag_mode",
        label   = "Hashtag Modus",
        onText  = "Hashtags",
        offText = "Normal",
        value   = TRUE    # <-- Hashtag Modus jetzt standardmäßig aktiviert
      )
    ),
    column(
      width = 3,
      sliderInput(
        "freq_range",
        "Häufigkeitsbereich",
        min   = 0,
        max   = 3000,
        value = c(0, 3000),
        step  = 1
      )
    ),
    column(
      width = 2,
      sliderInput(
        "max_words",
        "Max. Wortanzahl",
        min = 1,
        max = 3000,
        value = 500,
        step = 1
      )
    ),
    column(
      width = 3,
      textInput("search_term", "Suchbegriff:", "")
    )
  ),

  br(),

  wordcloud2Output("wordcloud", width = "100%", height = "600px"),
  DTOutput("filtered_tbl"),

  tags$script(HTML("
    $(document).on('click', '.wordcloud2-canvas', function(e) {
      var word = e.target.textContent;
      if (word) {
        Shiny.setInputValue('clicked_word', word, {priority: 'event'});
      }
    });
  "))
)

# -----------------------------
# 4) Server
# -----------------------------

server <- function(input, output, session) {

  # Kanal-Filter (uploader)
  df_filtered_uploader <- reactive({
    upl <- input$uploader_select
    if (is.null(upl)) {
      upl <- "ALLE"
    }
    if (upl == "ALLE") {
      df
    } else {
      df %>% filter(uploader == upl)
    }
  })

  # Wortfrequenzen
  word_counts_reactive <- reactive({
    sub_df <- df_filtered_uploader()

    # 1) Fallbacks für fehlende oder unvollständige Inputs:
    freq_range <- input$freq_range
    if (is.null(freq_range) || length(freq_range) < 2) {
      freq_range <- c(0, 3000)
    }

    max_words <- input$max_words
    if (is.null(max_words) || max_words < 1) {
      max_words <- 500
    }

    # 2) Hashtag-Modus abfragen mit Fallback
    hashtag_mode <- FALSE
    if (!is.null(input$hashtag_mode)) {
      hashtag_mode <- isTRUE(input$hashtag_mode)
    }

    # 3) Hashtags vs Normal
    if (hashtag_mode) {
      tmp <- sub_df %>%
        filter(!is.na(title)) %>%
        unnest_tokens(word, title, token = "regex", pattern = "\\s+") %>%
        filter(str_detect(word, "^#")) %>%
        count(word, sort = TRUE)
    } else {
      tmp <- sub_df %>%
        filter(!is.na(title)) %>%
        unnest_tokens(word, title) %>%
        anti_join(tibble(word = stopwords::stopwords("de")), by = "word") %>%
        filter(!grepl("^[0-9]+$", word)) %>%
        count(word, sort = TRUE)
    }

    # 4) Frequenzgrenzen anwenden
    tmp <- tmp %>%
      filter(n >= freq_range[1], n <= freq_range[2])

    # 5) Auf max_words beschränken
    head(tmp, max_words)
  })

  # Wortwolke
  output$wordcloud <- renderWordcloud2({
    wc_data <- word_counts_reactive()
    if (nrow(wc_data) == 0) {
      return(wordcloud2(data = data.frame(word = "Keine Wörter", freq = 1), size = 2))
    }
    my_palette <- c("#2ea9df", "#0073c0", "#ff2e17")
    wordcloud2(
      data             = wc_data,
      color            = rep_len(my_palette, nrow(wc_data)),
      size             = 5.2,
      backgroundColor  = "white"
    )
  })

  # Tabelle - Suchbegriff oder geklicktes Wort
  filtered_data <- reactive({
    sub_df <- df_filtered_uploader()

    srch <- input$search_term
    if (is.null(srch)) {
      srch <- ""
    }

    if (nzchar(srch)) {
      # Suche im Text
      search_term <- tolower(srch)
      sub_df %>%
        filter(str_detect(tolower(title), fixed(search_term))) %>%
        select(id, url, title)
    } else {
      # Klick in der Wolke
      cw <- input$clicked_word
      if (is.null(cw)) {
        # Falls kein Klick erfolgt -> leere Tabelle oder komplette Ausgabe
        return(head(sub_df %>% select(id, url, title), 0))
      }
      clicked_word <- str_remove(cw, ":[0-9]+$")
      sub_df %>%
        filter(str_detect(tolower(title), fixed(tolower(clicked_word)))) %>%
        select(id, url, title)
    }
  })

  output$filtered_tbl <- renderDT({
    datatable(
      filtered_data(),
      options = list(pageLength = 10),
      class   = "compact"
    )
  })
}

# -----------------------------
# 5) App starten
# -----------------------------

app_port <- 9432
app_host <- "0.0.0.0"

shinyApp(
  ui = ui,
  server = server,
  options = list(host = app_host, port = app_port, launch.browser = FALSE)
)
