#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# Shiny-App: Wortwolke mit Range-Slider für Häufigkeitsbereich
#             und Slider für maximale Wortanzahl (auf Deutsch).
# Angepasster Wertebereich: bis 2.500 für Frequenzen, bis 500 für Wortanzahl.

# -----------------------------
# Schritt 1: Installation der Pakete (falls nicht installiert)
# -----------------------------

required_packages <- c(
  "RSQLite", "DBI", "dplyr", "tidytext", "wordcloud2", 
  "stopwords", "shiny", "DT", "stringr"
)

install_if_missing <- function(packages) {
  installed <- installed.packages()[, "Package"]
  for (pkg in packages) {
    if(!(pkg %in% installed)){
      install.packages(pkg, dependencies = TRUE, repos = "http://cran.rstudio.com/")
    }
  }
}

install_if_missing(required_packages)

# -----------------------------
# Schritt 2: Laden der Pakete
# -----------------------------

library(RSQLite)
library(DBI)
library(dplyr)
library(tidytext)
library(wordcloud2)
library(stopwords)
library(shiny)
library(DT)
library(stringr)

# -----------------------------
# Schritt 3: Verbindung zur SQLite-Datenbank und Datenabruf
# -----------------------------

DB_PATH <- "media_metadata.db"  # Anpassen, falls der Dateiname anders lautet

if(!file.exists(DB_PATH)){
  stop(paste("Datenbankdatei nicht gefunden:", DB_PATH))
}

con <- dbConnect(SQLite(), DB_PATH)
tables <- dbListTables(con)
if(!"media_metadata" %in% tables){
  dbDisconnect(con)
  stop("Tabelle 'media_metadata' nicht in der Datenbank vorhanden.")
}

df <- dbReadTable(con, "media_metadata")
dbDisconnect(con)

if(!"title" %in% colnames(df)){
  stop("Spalte 'title' nicht in der Tabelle 'media_metadata' vorhanden.")
}
df$title <- as.character(df$title)

# -----------------------------
# Schritt 4: Eindeutige Uploader + "Alle" hinzufügen
# -----------------------------

uploader_choices <- c("Alle", sort(unique(df$uploader)))

# -----------------------------
# Schritt 5: Shiny-Benutzeroberfläche (UI)
# -----------------------------

ui <- fluidPage(
  titlePanel(""),
  
  sidebarLayout(
    sidebarPanel(
      selectInput(
        inputId = "selected_uploader",
        label = "Uploader auswählen oder suchen:",
        choices = uploader_choices,
        selected = "Alle",
        multiple = FALSE,
        selectize = TRUE
      ),
      actionButton("reset", "Reset"),
      br(),
      
      # Range-Slider für minimale und maximale Worthäufigkeit
      sliderInput("freq_range",
                  "Häufigkeitsbereich (von - bis):",
                  min = 1,
                  max = 2500,
                  value = c(3, 50),  # Beispielhafte Startwerte
                  step = 1),
      
      # Slider für maximale Anzahl an Wörtern in der Wortwolke
      sliderInput("max_words",
                  "Maximale Anzahl der Wörter:",
                  min = 1, max = 500, value = 100),
      
      br(),
      helpText(
        "Erläuterungen:",
        br(),
        "• 'Reset' setzt die Dropdown-Auswahl auf 'Alle' zurück.",
        br(),
        "• Der Häufigkeitsbereich-Slider legt fest, welche Wörter ",
        "  anhand ihrer Vorkommen im Titel berücksichtigt werden. ",
        "  (Beispiel: bei [3, 50] werden nur Wörter gezeigt, die ",
        "  mindestens 3-mal und höchstens 50-mal vorkamen.)",
        br(),
        "• Die 'Maximale Anzahl der Wörter' begrenzt zusätzlich die ",
        "  maximale Anzahl in der Wortwolke."
      )
    ),
    
    mainPanel(
      wordcloud2Output("wordcloud", width = "100%", height = "500px"),
      br(),
      DTOutput("filtered_tbl")
    )
  )
)

# -----------------------------
# Schritt 6: Server-Logik
# -----------------------------

server <- function(input, output, session) {
  
  # Reset-Knopf: Setzt den Uploader zurück auf "Alle"
  observeEvent(input$reset, {
    updateSelectInput(session, "selected_uploader", selected = "Alle")
  })
  
  # Daten filtern nach Uploader
  data_filtered <- reactive({
    if (input$selected_uploader == "Alle") {
      df
    } else {
      df %>% filter(uploader == input$selected_uploader)
    }
  })
  
  # Wort-Frequenzen berechnen
  word_counts <- reactive({
    data_subset <- data_filtered() %>%
      filter(!is.na(title)) %>%
      unnest_tokens(word, title) %>%
      anti_join(tibble(word = stopwords("de")), by = "word") %>%
      filter(!grepl("^[0-9]+$", word)) %>%
      count(word, sort = TRUE)
    
    # Range-Filter für die Worthäufigkeit
    freq_min <- input$freq_range[1]
    freq_max <- input$freq_range[2]
    
    data_subset <- data_subset %>%
      # Nur Wörter behalten, deren Häufigkeit innerhalb von [freq_min, freq_max] liegt
      filter(n >= freq_min & n <= freq_max)
    
    # Zusätzliche Begrenzung auf die gewünschten max_words
    data_subset <- data_subset %>%
      top_n(input$max_words, n)
    
    data_subset
  })
  
  # Erzeugung der Wortwolke
  output$wordcloud <- renderWordcloud2({
    df_wc <- word_counts()
    
    if (nrow(df_wc) == 0) {
      return(wordcloud2(data.frame(word = "Keine Titel gefunden", freq = 1),
                        size = 1))
    }
    
    # Farbpalette für Wortwolke
    my_palette <- c("#2ea9df", "#0073c0", "#ff2e17")
    
    wordcloud2(
      data = df_wc,
      color = rep_len(my_palette, nrow(df_wc)),
      size = 2.5,
      backgroundColor = "white"
    )
  })
  
  # Zufällig gemischte Datentabelle anzeigen
  output$filtered_tbl <- renderDT({
    data_subset <- data_filtered() %>%
      sample_frac(1) %>%
      select(id, url, title, uploader)
    
    datatable(
      data_subset,
      options = list(pageLength = 10)
    )
  })
}

# -----------------------------
# Schritt 7: Starten der Shiny-App
# -----------------------------

app_port <- 9432
app_host <- "0.0.0.0"

shinyApp(ui, server, options = list(host = app_host, port = app_port, launch.browser = FALSE))
