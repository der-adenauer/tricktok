#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# Erweiterte Shiny-App mit Reset-Knopf, Zufallsanzeige und zwei Slidern
# zur Steuerung der Wortwolke

# -----------------------------
# Schritt 1: Installation der Pakete (falls nicht installiert)
# -----------------------------

required_packages <- c(
  "RSQLite", "DBI", "dplyr", "tidytext", "wordcloud2", 
  "stopwords", "shiny", "DT", "stringr"
)

install_if_missing <- function(packages) {
  installed <- installed.packages()[, "Package"]
  for(pkg in packages){
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

DB_PATH <- "media_metadata.db"

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
  titlePanel("Wortwolke mit Steuerung und Reset"),
  
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
      sliderInput("min_freq",
                  "Minimum Frequency:",
                  min = 1, max = 50, value = 3),
      sliderInput("max_words",
                  "Maximum Number of Words:",
                  min = 1, max = 300, value = 100),
      br(),
      helpText("Reset setzt die Dropdown-Auswahl auf 'Alle' zurück. 
               Slider steuern Wortwolke basierend auf Worthäufigkeit.")
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
  
  observeEvent(input$reset, {
    updateSelectInput(session, "selected_uploader", selected = "Alle")
  })
  
  data_filtered <- reactive({
    if (input$selected_uploader == "Alle") {
      df
    } else {
      df %>% filter(uploader == input$selected_uploader)
    }
  })
  
  word_counts <- reactive({
    data_subset <- data_filtered() %>%
      filter(!is.na(title)) %>%
      unnest_tokens(word, title) %>%
      anti_join(tibble(word = stopwords::stopwords("de")), by = "word") %>%
      filter(!grepl("^[0-9]+$", word)) %>%
      count(word, sort = TRUE)
    
    # Anwendung der Slider-Filter:
    data_subset <- data_subset %>%
      filter(n >= input$min_freq) %>%
      top_n(input$max_words, n)
    
    data_subset
  })
  
  output$wordcloud <- renderWordcloud2({
    df_wc <- word_counts()
    
    if (nrow(df_wc) == 0) {
      return(wordcloud2(data.frame(word = "Keine Titel gefunden", freq = 1), size = 1))
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
  
  output$filtered_tbl <- renderDT({
    data_subset <- data_filtered() %>%
      sample_frac(1) %>%  # Zufällige Reihenfolge
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
