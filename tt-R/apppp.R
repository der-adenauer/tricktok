# Keine Personalpronomen in Kommentaren oder Texten

library(shiny)
library(DBI)
library(RPostgres)
library(dplyr)
library(DT)
library(pool)

db_pool <- dbPool(
  drv      = RPostgres::Postgres(),
  host     = "188.245.249.154",
  port     = 5432,
  dbname   = "tiktokdb",
  user     = "tiktok_writer",
  password = "Wr!T3r_92@kLm"
)

ui <- fluidPage(
  titlePanel("Foto-Suche"),
  fluidRow(
    column(
      width = 6,
      textInput("search", "Suchbegriff eingeben")
    ),
    column(
      width = 2,
      actionButton("go", "Suchen", class = "btn-primary", style = "margin-top:25px;")
    )
  ),
  fluidRow(
    column(
      width = 12,
      hr(),
      DTOutput("ergebnisTabelle")
    )
  )
)

server <- function(input, output, session) {
  
  tabellenDaten <- reactiveVal(data.frame())
  
  observeEvent(input$go, {
    suchbegriff <- paste0("%", input$search, "%")
    
    # Gesamte Ergebnismenge abfragen (keine LIMIT) 
    abfrage <- "
      SELECT 
        id,
        url,
        title,
        ocr_text,
        public_links,
        timestamp
      FROM photo_media
      WHERE title ILIKE $1
         OR ocr_text ILIKE $1
    "
    
    ergebnis <- dbGetQuery(db_pool, abfrage, params = list(suchbegriff))
    
    # Relevante Spalten zu Text konvertieren, um Formatprobleme zu vermeiden
    spalten <- c("id", "title", "ocr_text", "url", "public_links")
    for (sp in spalten) {
      if (sp %in% colnames(ergebnis)) {
        ergebnis[[sp]] <- as.character(ergebnis[[sp]])
      }
    }
    
    # Timestamp verarbeiten (numerische Unix-Epoche vs. bereits lesbarer String)
    if ("timestamp" %in% colnames(ergebnis)) {
      suppressWarnings({
        numeric_ts <- as.numeric(ergebnis$timestamp)
      })
      human_times <- rep(NA_character_, length(numeric_ts))
      
      # Wo numeric_ts nicht NA -> als Unix-Zeit interpretieren
      idx_ok <- which(!is.na(numeric_ts))
      if (length(idx_ok) > 0) {
        human_times[idx_ok] <- format(
          as.POSIXct(numeric_ts[idx_ok], origin = "1970-01-01"),
          "%Y-%m-%d %H:%M:%S"
        )
      }
      
      # Wo numeric_ts NA ist, Wert als String beibehalten
      idx_str <- which(is.na(numeric_ts) & !is.na(ergebnis$timestamp))
      if (length(idx_str) > 0) {
        human_times[idx_str] <- ergebnis$timestamp[idx_str]
      }
      
      ergebnis$timestamp <- human_times
    }
    
    # Pro Datensatz eine HTML-Darstellung:
    #   - Erste "Reihe": Bilder, in einer Zeile nebeneinander
    #   - Zweite "Reihe": Titel, OCR, Zeit (nebeneinander)
    # Bootstrap-Layout per row/col
    ergebnis <- ergebnis %>%
      rowwise() %>%
      mutate(
        bilder_html = {
          pl_links <- ifelse(is.na(public_links), "", public_links)
          links <- unlist(strsplit(pl_links, "\n"))
          links_bilder <- links[grepl("\\.(jpg|jpeg|png)$", links, ignore.case = TRUE)]
          if (length(links_bilder) == 0) {
            ""
          } else {
            # 400px-Höhe für jedes Bild
            paste0(
              sapply(links_bilder, function(link) {
                paste0(
                  "<img src='", link, 
                  "' style='height:400px; margin:5px; vertical-align:middle;'/>"
                )
              }),
              collapse = ""
            )
          }
        },
        meta_html = {
          id_val <- ifelse(!is.na(id), id, "")
          title_val <- ifelse(!is.na(title), title, "")
          ocr_val <- ifelse(!is.na(ocr_text), ocr_text, "")
          time_str <- if ("timestamp" %in% colnames(.) && !is.na(timestamp)) {
            timestamp
          } else {
            ""
          }
          
          # Layout in einer Zeile
          paste0(
            "<strong>ID:</strong> ", id_val, " | ",
            "<strong>Titel:</strong> ", title_val, " | ",
            "<strong>OCR:</strong> ", ocr_val, " | ",
            "<strong>Time:</strong> ", time_str
          )
        },
        row_html = paste0(
          "<div class='container' style='border:1px solid #ccc; padding:10px; margin-bottom:20px;'>",
            "<div class='row'>",
              "<div class='col-sm-12' style='text-align:center;'>",
                bilder_html,
              "</div>",
            "</div>",
            "<div class='row' style='margin-top:10px;'>",
              "<div class='col-sm-12'>",
                meta_html,
              "</div>",
            "</div>",
          "</div>"
        )
      ) %>%
      ungroup()
    
    # Nur row_html für Ausgabe
    tabellenDaten(ergebnis %>% select(row_html))
  })
  
  output$ergebnisTabelle <- renderDT({
    datatable(
      tabellenDaten(),
      escape = FALSE,
      # Länge der Seite und Auswahlmenü für Nutzer (10,25,50,100, oder Alle)
      options = list(
        pageLength = 10,
        lengthMenu = list(c(10, 25, 50, 100, -1),
                          c('10', '25', '50', '100', 'Alle')),
        scrollX    = TRUE
      ),
      rownames = FALSE
    )
  })
  
  onSessionEnded(function() {
    poolClose(db_pool)
  })
}

cat("==== Starting shinyApp ====\n")
shinyApp(
  ui = ui,
  server = server,
  options = list(host = "0.0.0.0", port = 4070, launch.browser = FALSE)
)
