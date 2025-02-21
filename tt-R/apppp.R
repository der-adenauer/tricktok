

library(shiny)
library(DBI)
library(RPostgres)
library(dplyr)
library(DT)
library(pool)
library(dotenv)

# .env laden
load_dot_env(".env")

# Gemeinsamer Pool
db_pool <- dbPool(
  drv      = RPostgres::Postgres(),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  dbname   = Sys.getenv("DB_NAME"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASS")
)

# Hilfsfunktion für saubere Strings
safe_str <- function(x) {
  if (is.null(x)) return("")
  if (length(x) == 0) return("")
  if (all(is.na(x))) return("")
  if (is.character(x) && length(x) > 1) x <- x[1]
  if (is.na(x)) return("")
  as.character(x)
}

ui <- fluidPage(
  titlePanel("Tricktok Photo-Archiv"),
  
  fluidRow(
    column(width = 3, textInput("search", "Suchbegriff eingeben")),
    column(width = 1, actionButton("go", "Suchen", class = "btn-primary", style = "margin-top:25px;")),
    column(width = 3, dateRangeInput("dateRange", "Zeitraum (Timestamp)",
                                     start = NA, end = NA,
                                     format = "yyyy-mm-dd", startview = "month")),
    column(width = 1, actionButton("resetDate", "Reset Datum", style="margin-top:25px;")),
    column(width = 4, selectInput("uploader", "Uploader auswählen", 
                                  choices = c("Alle"), selected = "Alle"))
  ),
  
  hr(),
  
  # Manuelle Sortier-Buttons
  fluidRow(
    column(
      width = 12,
      tags$b("Manuelle Sortierung: "),
      actionButton("sortViewsAsc",   "Views ↑"),
      actionButton("sortViewsDesc",  "↓"),
      tags$span(style="margin-right:20px;"),
      
      actionButton("sortLikesAsc",   "Likes ↑"),
      actionButton("sortLikesDesc",  "↓"),
      tags$span(style="margin-right:20px;"),
      
      actionButton("sortRepostsAsc", "Reposts ↑"),
      actionButton("sortRepostsDesc","↓"),
      tags$span(style="margin-right:20px;"),
      
      actionButton("sortComAsc",     "Comments ↑"),
      actionButton("sortComDesc",    "↓")
    )
  ),
  
  hr(),
  
  fluidRow(
    column(
      width = 12,
      DTOutput("ergebnisTabelle")
    )
  )
)

server <- function(input, output, session) {
  
  # Auswahlliste Uploader befüllen
  observe({
    con <- poolCheckout(db_pool)
    on.exit(poolReturn(con))
    
    uploader_res <- dbGetQuery(con, "
      SELECT DISTINCT uploader
      FROM photo_media
      WHERE uploader IS NOT NULL
      ORDER BY uploader
    ")
    choices <- c("Alle", uploader_res$uploader)
    updateSelectInput(session, "uploader", choices=choices, selected="Alle")
  })
  
  # Datum reset
  observeEvent(input$resetDate, {
    updateDateRangeInput(session, "dateRange", start = NA, end = NA)
  })
  
  # Ablage roher Daten (inkl. numeric-Spalten)
  rawData <- reactiveVal(data.frame())
  
  # End-Datatable => nur row_html
  tableData <- reactiveVal(data.frame(row_html=character(0)))
  
  # Aktualisierung von tableData() => nur row_html
  updateTable <- function(df) {
    tableData(data.frame(row_html = df$row_html))
  }
  
  # row_html + numeric
  buildRowHTML <- function(df) {
    df <- df %>%
      rowwise() %>%
      mutate(
        bilder_html = {
          pl_links <- safe_str(p_public_links)
          links <- unlist(strsplit(pl_links, "\n"))
          pics <- links[grepl("\\.(jpg|jpeg|png)$", links, ignore.case=TRUE)]
          if (length(pics)==0) {
            ""
          } else {
            paste0(
              sapply(pics, function(x) {
                paste0("<img src='", x, "' style='height:400px; margin:5px; vertical-align:middle;'/>")
              }),
              collapse=""
            )
          }
        },
        audio_html = {
          pl_links <- safe_str(p_public_links)
          links <- unlist(strsplit(pl_links, "\n"))
          audios <- links[grepl("\\.(mp3|m4a)$", links, ignore.case=TRUE)]
          if (length(audios)==0) {
            ""
          } else {
            paste0(
              sapply(audios, function(aud) {
                ftype <- if (grepl("\\.m4a$", aud, ignore.case=TRUE)) "audio/mp4" else "audio/mpeg"
                paste0("<audio src='", aud, "' type='", ftype,
                       "' controls style='margin:5px; width:300px; vertical-align:middle;'></audio>")
              }),
              collapse=""
            )
          }
        },
        meta_html = {
          up     <- safe_str(p_uploader)
          urlval <- safe_str(p_url)
          trk    <- safe_str(p_track)
          ttl    <- safe_str(p_title)
          descr  <- safe_str(p_description)
          dur    <- safe_str(p_duration)
          vc     <- safe_str(view_count)
          lc     <- safe_str(like_count)
          rc     <- safe_str(repost_count)
          cc     <- safe_str(comment_count)
          ocrv   <- safe_str(p_ocr_text)
          tstamp <- safe_str(p_timestamp)
          
          url_link <- if (nzchar(urlval)) {
            paste0("<a href='", urlval, "' target='_blank'>", urlval, "</a>")
          } else ""
          
          paste0(
            "<strong>Uploader:</strong> ", up, "<br/>",
            "<strong>URL:</strong> ", url_link, "<br/>",
            "<strong>Track:</strong> ", trk, "<br/>",
            "<strong>Titel:</strong> ", ttl, "<br/>",
            "<strong>Beschreibung:</strong> ", descr, "<br/>",
            "<strong>Dauer:</strong> ", dur, "s<br/>",
            "<strong>Views:</strong> ", vc, " | ",
            "<strong>Likes:</strong> ", lc, " | ",
            "<strong>Reposts:</strong> ", rc, " | ",
            "<strong>Comments:</strong> ", cc, "<br/>",
            "<strong>OCR:</strong> ", ocrv, "<br/>",
            "<strong>Time:</strong> ", tstamp
          )
        },
        row_html = paste0(
          "<div class='container' style='border:1px solid #ccc; padding:10px; margin-bottom:20px;'>",
            "<div class='row'>",
              "<div class='col-sm-12' style='text-align:center;'>", bilder_html, "</div>",
            "</div>",
            "<div class='row' style='margin-top:10px;'>",
              "<div class='col-sm-12' style='text-align:center;'>", audio_html, "</div>",
            "</div>",
            "<div class='row' style='margin-top:10px;'>",
              "<div class='col-sm-12'>", meta_html, "</div>",
            "</div>",
          "</div>"
        )
      ) %>%
      ungroup()
    
    df$Views    <- suppressWarnings(as.numeric(df$view_count))
    df$Likes    <- suppressWarnings(as.numeric(df$like_count))
    df$Reposts  <- suppressWarnings(as.numeric(df$repost_count))
    df$Comments <- suppressWarnings(as.numeric(df$comment_count))
    
    df
  }
  
  # Initialer Zufalls-Ladevorgang, once=TRUE
  observeEvent(TRUE, {
    isolate({
      loadRandom()
    })
  }, once=TRUE)
  
  # "Suchen"-Knopf
  observeEvent(input$go, {
    doSearch()
  })
  
  # Sortier-Buttons
  observeEvent(input$sortViewsAsc, {
    df <- rawData()
    if(nrow(df)==0)return()
    df <- df[order(df$Views, decreasing=FALSE),]
    rawData(df)
    updateTable(df)
  })
  observeEvent(input$sortViewsDesc, {
    df <- rawData()
    if(nrow(df)==0)return()
    df <- df[order(df$Views, decreasing=TRUE),]
    rawData(df)
    updateTable(df)
  })
  
  observeEvent(input$sortLikesAsc, {
    df <- rawData()
    if(nrow(df)==0)return()
    df <- df[order(df$Likes, decreasing=FALSE),]
    rawData(df)
    updateTable(df)
  })
  observeEvent(input$sortLikesDesc, {
    df <- rawData()
    if(nrow(df)==0)return()
    df <- df[order(df$Likes, decreasing=TRUE),]
    rawData(df)
    updateTable(df)
  })
  
  observeEvent(input$sortRepostsAsc, {
    df <- rawData()
    if(nrow(df)==0)return()
    df <- df[order(df$Reposts, decreasing=FALSE),]
    rawData(df)
    updateTable(df)
  })
  observeEvent(input$sortRepostsDesc, {
    df <- rawData()
    if(nrow(df)==0)return()
    df <- df[order(df$Reposts, decreasing=TRUE),]
    rawData(df)
    updateTable(df)
  })
  
  observeEvent(input$sortComAsc, {
    df <- rawData()
    if(nrow(df)==0)return()
    df <- df[order(df$Comments, decreasing=FALSE),]
    rawData(df)
    updateTable(df)
  })
  observeEvent(input$sortComDesc, {
    df <- rawData()
    if(nrow(df)==0)return()
    df <- df[order(df$Comments, decreasing=TRUE),]
    rawData(df)
    updateTable(df)
  })
  
  # DataTable
  output$ergebnisTabelle <- renderDT({
    datatable(
      tableData(),
      escape = FALSE,
      options = list(
        pageLength = 10,
        lengthMenu = list(c(10,25,50,1000),
                          c('10','25','50','1000')),
        scrollX = TRUE
      ),
      rownames = FALSE
    )
  })
  
  # Zufallsfunktion
  loadRandom <- function() {
    rndQuery <- "
      WITH combined AS (
        SELECT
          p.id AS p_id,
          p.url AS p_url,
          p.uploader AS p_uploader,
          p.track AS p_track,
          p.title AS p_title,
          p.ocr_text AS p_ocr_text,
          p.public_links AS p_public_links,
          p.timestamp AS p_timestamp,
          p.description AS p_description,
          p.duration AS p_duration,
          COALESCE(m.view_count,0)    AS view_count,
          COALESCE(m.like_count,0)    AS like_count,
          COALESCE(m.repost_count,0)  AS repost_count,
          COALESCE(m.comment_count,0) AS comment_count
        FROM photo_media p
        LEFT JOIN media_metadata m ON p.url = m.url
      )
      SELECT *
      FROM combined
      ORDER BY random()
      LIMIT 10
    "
    con <- poolCheckout(db_pool)
    on.exit(poolReturn(con))
    df <- tryCatch({
      dbGetQuery(con, rndQuery)
    }, error=function(e){
      warning("DB Fehler (Zufall): ", e$message)
      data.frame()
    })
    if(nrow(df)==0){
      tableData(data.frame(row_html="Keine Zufalls-Einträge."))
      rawData(data.frame())
      return()
    }
    needed <- c("p_id","p_url","p_uploader","p_track","p_title","p_ocr_text",
                "p_public_links","p_timestamp","p_description","p_duration",
                "view_count","like_count","repost_count","comment_count")
    for(sp in needed) {
      if(!sp %in% names(df)){ df[[sp]]<-"" } else {
        df[[sp]]<-as.character(df[[sp]])
      }
    }
    
    nts <- suppressWarnings(as.numeric(df$p_timestamp))
    hts <- rep("", nrow(df))
    i_ok <- which(!is.na(nts))
    if(length(i_ok)>0){
      hts[i_ok] <- format(as.POSIXct(nts[i_ok], origin="1970-01-01"),"%Y-%m-%d %H:%M:%S")
    }
    i_str <- which(is.na(nts)&nzchar(df$p_timestamp))
    if(length(i_str)>0){
      hts[i_str] <- df$p_timestamp[i_str]
    }
    df$p_timestamp <- hts
    
    df <- buildRowHTML(df)
    rawData(df)
    updateTable(df)
  }
  
  # Such-Funktion
  doSearch <- function() {
    sb <- paste0("%", input$search, "%")
    up <- input$uploader
    dr <- input$dateRange
    
    baseQuery <- "
      WITH combined AS (
        SELECT
          p.id AS p_id,
          p.url AS p_url,
          p.uploader AS p_uploader,
          p.track AS p_track,
          p.title AS p_title,
          p.ocr_text AS p_ocr_text,
          p.public_links AS p_public_links,
          p.timestamp AS p_timestamp,
          p.description AS p_description,
          p.duration AS p_duration,
          COALESCE(m.view_count,0)    AS view_count,
          COALESCE(m.like_count,0)    AS like_count,
          COALESCE(m.repost_count,0)  AS repost_count,
          COALESCE(m.comment_count,0) AS comment_count
        FROM photo_media p
        LEFT JOIN media_metadata m ON p.url = m.url
      )
      SELECT *
      FROM combined
      WHERE (p_title ILIKE $1 OR p_ocr_text ILIKE $1)
    "
    paramList <- list(sb)
    idx <- 1
    
    # Datum
    valStart <- FALSE
    valEnd   <- FALSE
    if(!all(is.na(dr))){
      st <- try(as.numeric(as.POSIXct(dr[1])), silent=TRUE)
      ed <- try(as.numeric(as.POSIXct(dr[2]))+86400-1, silent=TRUE)
      if(!inherits(st,"try-error") && !is.na(st) &&
         !inherits(ed,"try-error") && !is.na(ed)) {
        valStart <- TRUE; valEnd <- TRUE
      }
      if(valStart && valEnd){
        baseQuery <- paste0(baseQuery," AND p_timestamp >= $",idx+1," AND p_timestamp <= $",idx+2)
        paramList[[idx+1]] <- st
        paramList[[idx+2]] <- ed
        idx <- idx+2
      }
    }
    
    if(!is.null(up) && up!="Alle"){
      baseQuery<-paste0(baseQuery," AND p_uploader = $",idx+1)
      paramList[[idx+1]]<-up
      idx<-idx+1
    }
    
    con <- poolCheckout(db_pool)
    on.exit(poolReturn(con))
    df <- tryCatch({
      dbGetQuery(con, baseQuery, params=paramList)
    }, error=function(e){
      warning("DB Fehler (Search): ", e$message)
      data.frame()
    })
    if(nrow(df)==0){
      tableData(data.frame(row_html="Keine Einträge gefunden."))
      rawData(data.frame())
      return()
    }
    
    needed <- c("p_id","p_url","p_uploader","p_track","p_title","p_ocr_text",
                "p_public_links","p_timestamp","p_description","p_duration",
                "view_count","like_count","repost_count","comment_count")
    for(sp in needed){
      if(!sp %in% names(df)){ df[[sp]]<-"" } else {
        df[[sp]]<-as.character(df[[sp]])
      }
    }
    nts <- suppressWarnings(as.numeric(df$p_timestamp))
    hts <- rep("", nrow(df))
    i_ok <- which(!is.na(nts))
    if(length(i_ok)>0){
      hts[i_ok]<-format(as.POSIXct(nts[i_ok], origin="1970-01-01"),"%Y-%m-%d %H:%M:%S")
    }
    i_str <- which(is.na(nts) & nzchar(df$p_timestamp))
    if(length(i_str)>0){
      hts[i_str] <- df$p_timestamp[i_str]
    }
    df$p_timestamp <- hts
    
    df <- buildRowHTML(df)
    rawData(df)
    updateTable(df)
  }
}

cat("==== Starting shinyApp ====\n")
shinyApp(ui=ui, server=server, options=list(host="0.0.0.0", port=4070, launch.browser=FALSE))
