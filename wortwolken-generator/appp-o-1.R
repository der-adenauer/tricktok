#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# interactive_wordcloud_app.R
# Dieses Skript erstellt eine interaktive Wortwolke mit Shiny basierend auf Daten aus einer SQLite-Datenbank.
# Es ist für die Ausführung auf einer entfernten Maschine konfiguriert und öffnet keinen Browser automatisch.

# -----------------------------
# Schritt 1: Installation der Pakete (falls nicht installiert)
# -----------------------------

# Liste der benötigten Pakete
required_packages <- c("RSQLite", "DBI", "dplyr", "tidytext", "wordcloud2", 
                       "stopwords", "shiny", "DT", "stringr")

# Funktion zur Installation fehlender Pakete
install_if_missing <- function(packages) {
  installed <- installed.packages()[,"Package"]
  for(pkg in packages){
    if(!(pkg %in% installed)){
      install.packages(pkg, dependencies = TRUE, repos = "http://cran.rstudio.com/")
    }
  }
}

# Installiere fehlende Pakete
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
# Schritt 3: Verbindung zur SQLite-Datenbank herstellen und Daten abrufen
# -----------------------------

# Definiere den Pfad zur Datenbank
DB_PATH <- "media_metadata.db"

# Überprüfe, ob die Datenbankdatei existiert
if(!file.exists(DB_PATH)){
  stop(paste("Die Datenbankdatei wurde nicht gefunden:", DB_PATH))
}

# Stelle eine Verbindung zur SQLite-Datenbank her
con <- dbConnect(RSQLite::SQLite(), DB_PATH)

# Überprüfe, ob die Tabelle 'media_metadata' existiert
tables <- dbListTables(con)
if(!"media_metadata" %in% tables){
  dbDisconnect(con)
  stop("Die Tabelle 'media_metadata' existiert nicht in der Datenbank.")
}

# Lese die Tabelle 'media_metadata' in einen DataFrame
df <- dbReadTable(con, "media_metadata")

# Schließe die Datenbankverbindung
dbDisconnect(con)

# Sicherstellen, dass die Spalte 'title' als Zeichenkette vorliegt
if(!"title" %in% colnames(df)){
  stop("Die Spalte 'title' wurde in der Tabelle 'media_metadata' nicht gefunden.")
}
df$title <- as.character(df$title)

# -----------------------------
# Schritt 4: Textverarbeitung
# -----------------------------

# Textverarbeitung: Tokenisierung, Entfernen von Stoppwörtern und Zählen der Wortfrequenzen
word_counts <- df %>%
  filter(!is.na(title)) %>%
  unnest_tokens(word, title) %>%
  # Entferne Stoppwörter in deutscher Sprache
  anti_join(tibble(word = stopwords::stopwords("de")), by = "word") %>%
  # Entferne Wörter, die nur aus Zahlen bestehen
  filter(!grepl("^[0-9]+$", word)) %>%
  # Zähle die Häufigkeit der Wörter
  count(word, sort = TRUE) %>%
  # Filtere Wörter mit einer Häufigkeit größer als 10
  filter(n > 10)

# Überprüfe die häufigsten Wörter
print(head(word_counts, 20))

# -----------------------------
# Schritt 5: Definieren der benutzerdefinierten Farbpalette
# -----------------------------

my_palette <- c("#355070",
                "#6d597a",
                "#b56576",
                "#e56b6f",
                "#eaac8b")

# -----------------------------
# Schritt 6: Definition der Shiny-App
# -----------------------------

# Benutzeroberfläche (UI) der Shiny-App
ui <- fluidPage(
  titlePanel("Interaktive Wortwolke"),
  
  # Wortwolke anzeigen
  wordcloud2Output("wordcloud"),
  
  # Tabelle anzeigen
  DTOutput("filtered_tbl"),
  
  # JavaScript zur Erfassung von Klickereignissen auf der Wortwolke
  tags$script(HTML(
    "
    // Event-Listener für Klicks auf die Wortwolke
    $(document).on('click', '.wordcloud2-text', function(e) {
      var word = $(this).text();
      if(word){
        Shiny.setInputValue('clicked_word', word, {priority: 'event'});
      }
    });
    "
  ))
)

# Server-Logik der Shiny-App
server <- function(input, output, session) {
  
  # Render die Wortwolke
  output$wordcloud <- renderWordcloud2({
    wordcloud2(
      data = word_counts,
      color = rep_len(my_palette, nrow(word_counts)),
      size = 1.6,
      backgroundColor = "white"
    )
  })
  
  # Reaktive Funktion zur Filterung der Daten basierend auf dem geklickten Wort
  filtered_data <- reactive({
    req(input$clicked_word)
    clicked_word <- str_remove(input$clicked_word, ":[0-9]+$")
    
    df %>%
      filter(str_detect(tolower(title), fixed(tolower(clicked_word)))) %>%
      select(id, url, title)
  })
  
  # Render die gefilterte Tabelle
  output$filtered_tbl <- renderDT({
    datatable(filtered_data(), options = list(pageLength = 10))
  })
}

# -----------------------------
# Schritt 7: Starten der Shiny-App ohne Browser zu öffnen
# -----------------------------

# Definiere die Portnummer und Host (0.0.0.0 für alle Verbindungen)
app_port <- 9432  # Geänderter Port
app_host <- "0.0.0.0"  # Hört auf allen Netzwerk-Schnittstellen

# Starte die Shiny-App
shinyApp(ui, server, options = list(host = app_host, port = app_port, launch.browser = FALSE))
