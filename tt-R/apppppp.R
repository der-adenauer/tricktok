# app.R

library(shiny)
library(shinyjs)        # Für runjs()
library(DBI)
library(dplyr)
library(RPostgres)
library(DT)
library(pool)
library(dotenv)
library(stringr)

# .env laden
load_dot_env(".env")

pool <- dbPool(
  drv      = Postgres(),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  dbname   = Sys.getenv("DB_NAME"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASS")
)

onStop(function(){
  poolClose(pool)
})

###############################################################################
# Hilfsfunktionen (keine Personalpronomen in Kommentaren)
###############################################################################

# Bild auswählen
bildFuerTrack <- function(links) {
  bilder <- links[grepl("\\.(jpg|jpeg|png)$", links, ignore.case=TRUE)]
  if (length(bilder) == 0) return(NULL)
  sample(bilder, 1)
}

# Audio auswählen
audioFuerTrack <- function(links) {
  audios <- links[grepl("\\.(mp3|m4a)$", links, ignore.case=TRUE)]
  if (length(audios) == 0) return(NULL)
  sample(audios, 1)
}

# Daten aus DB laden
ladeTracksMitSummen <- function(con){
  qry <- "
    WITH pm AS (
      SELECT
        id,
        url,
        track,
        album,
        artists,
        timestamp,
        public_links,
        duration,
        description,
        title,
        COALESCE(view_count,0)    AS view_count,
        COALESCE(like_count,0)    AS like_count,
        COALESCE(repost_count,0)  AS repost_count,
        COALESCE(comment_count,0) AS comment_count
      FROM (
        SELECT
          p.id,
          p.url,
          p.track,
          p.album,
          p.artists,
          p.timestamp,
          p.public_links,
          p.duration,
          p.description,
          p.title,
          m.view_count,
          m.like_count,
          m.repost_count,
          m.comment_count
        FROM photo_media p
        LEFT JOIN media_metadata m
          ON p.url = m.url
        WHERE public_links ILIKE '%mp3%'
           OR public_links ILIKE '%m4a%'
      ) sub
    )
    SELECT * 
    FROM pm
  "
  df <- dbGetQuery(con, qry)
  
  # Zeitstempel konvertieren (falls numerisch)
  if ("timestamp" %in% names(df)){
    numericVals <- suppressWarnings(as.numeric(df$timestamp))
    idxOk <- which(!is.na(numericVals))
    humanVals <- rep("", nrow(df))
    if (length(idxOk) > 0){
      humanVals[idxOk] <- format(
        as.POSIXct(numericVals[idxOk], origin="1970-01-01"),
        "%Y-%m-%d %H:%M:%S"
      )
    }
    df$timestamp <- ifelse(humanVals=="", df$timestamp, humanVals)
  }
  
  df
}

###############################################################################
# UI
###############################################################################

ui <- fluidPage(
  useShinyjs(),
  
  # Meta-Viewport für mobile Geräte
  tags$head(
    tags$meta(name="viewport", content="width=device-width, initial-scale=1.0"),
    tags$style(HTML("
      html, body {
        margin: 0;
        padding: 0;
        display: grid;
        place-items: center;
        background: #fff;
      }
      
      /* Navbar minimiert, kein Titel */
      .navbar.navbar-default .container-fluid {
        display: flex !important;
        justify-content: center !important;
        text-align: center !important;
      }
      .navbar-nav {
        float: none !important;
        margin: 0 auto !important;
      }
      .navbar-brand {
        float: none !important;
      }
      
      /* Container für den Player: zentriert */
      .container-player {
        margin: 0 auto;
        text-align: center;
        width: 100vw;
        height: calc(100vh - 60px);
        display: flex;
        justify-content: center;
        align-items: center;
      }
      
      /* iPhone-Box */
      .iphone {
        width: 312px;
        height: 612px;
        max-width: 90vw; /* Anpassen an mobile Geräte */
        max-height: 90vh;
        background: #e0e5ec;
        border-radius: 2em;
        box-sizing: border-box;
        padding: 2em;
        display: flex;
        flex-direction: column;
        box-shadow: -5px -5px 15px 0px #ffffff9e, 5px 5px 15px 0px #a3b1c6a8;
      }
      .iphone .title {
        display: flex;
        justify-content: space-between;
        font-size: 0.75em;
        margin-bottom: 2em;
      }
      
      .album-cover {
        position: relative;
        display: flex;
        flex-direction: column;
        align-items: center;
      }
      .album-overlay {
        background: #ffffff;
        width: 248px;
        height: 248px;
        max-width: 70vw;
        max-height: 70vw;
        z-index: 2;
        border-radius: 15px;
        position: absolute;
        opacity: 0.35;
        clip-path: ellipse(61% 64% at 82% 56%);
      }
      .album-cover img {
        width: 248px;
        height: 248px;
        max-width: 70vw;
        max-height: 70vw;
        object-fit: cover;
        border-radius: 15px;
      }
      .song-title {
        text-align: center;
        margin-bottom: 0;
        margin-top: 10px;
        color: #6c7987;
      }
      .entry-id {
        text-align: center;
        margin: 0;
        margin-top: 5px;
        font-size: 0.7em;
        color: #999;
      }
      .artist-title {
        text-align: center;
        margin: 0;
        padding: 0.5em 0 1em 0;
        font-size: 0.85em;
        color: #6c7987;
      }
      .buttons {
        display: flex;
        justify-content: space-around;
        padding: 1em 0;
      }
      .btn {
        padding: 10px 14px;
        border-radius: 30px;
        color: #333;
        background: #e0e5ec;
        border: none;
        font-size: 1em;
        outline: none;
        cursor: pointer;
        box-shadow: -5px -5px 15px 0px #ffffff9e, 5px 5px 15px 0px #a3b1c6a8;
      }
      .btn:active {
        box-shadow: inset -5px -5px 15px 0px #ffffff9e, inset 5px 5px 15px 0px #a3b1c6a8;
      }
      .track-bar {
        margin-top: 1em;
        height: 10px;
        width: 100%;
        border-radius: 15px;
        background: #e0e5ec;
        box-shadow: -5px -5px 15px 0px #ffffff9e, 5px 5px 15px 0px #a3b1c6a8;
        display: flex;
        align-items: center;
      }
      .track-bar .progress {
        background: #7e8a98;
        opacity: 0.75;
        height: 100%;
        border-radius: 15px;
      }
      .lyrics {
        color: #7e8a98;
        margin-top: 2em;
        text-align: center;
        font-size: 0.75em;
        display: flex;
        flex-direction: column;
      }
      .navbar {
        margin-bottom: 0;
      }
      .tab-content {
        margin-top: 10px;
      }
      
      .container-player .col-sm-12 {
        display: flex;
        justify-content: center;
      }
    "))
  ),
  
  # Hauptbereich: Player
  fluidRow(
    class = "container-player",
    column(
      width=12,
      div(
        class="iphone",
        
        div(
          class="title",
          actionButton("randomTrack", "...", class="btn"),
          div("NOW PLAYING"),
          div("...")
        ),
        
        div(
          class="album-cover",
          div(class="album-overlay"),
          uiOutput("coverImgUI"),
          h2(class="song-title", textOutput("songTitle")),
          p(class="entry-id", textOutput("entryID")),
          h3(class="artist-title", textOutput("artistTitle"))
        ),
        
        div(
          class="buttons",
          actionButton("prevTrack", "<",  class="btn"),
          actionButton("playPause","II", class="btn"),
          actionButton("nextTrack",">",  class="btn")
        ),
        
        div(
          class="track-bar",
          div(class="progress", style="width:0%;", id="progressDiv")
        ),
        
        div(
          class="lyrics",
          textOutput("viewCountLabel")
        )
      )
    )
  ),
  
  # Unsichtbarer Audio-Player
  tags$audio(
    id="audioPlayer",
    src="",
    controls=NA,
    style="display:none;"
  ),
  
  # Tabs: Zuerst "Best of", dann "Top 100"
  navbarPage(
    title = NULL,
    id    = "mainNav",
    
    tabPanel(
      "Best of",
      fluidRow(
        column(width=12, DTOutput("bestOfTable"))
      )
    ),
    
    tabPanel(
      "Top 100",
      fluidRow(
        column(width=12, DTOutput("top100table"))
      )
    )
  )
)

###############################################################################
# SERVER
###############################################################################

server <- function(input, output, session){
  
  # Laden aller Rohdaten
  dataAll <- reactive({
    con <- poolCheckout(pool)
    on.exit(poolReturn(con))
    df <- ladeTracksMitSummen(con)
    if(nrow(df)==0) return(data.frame())
    df
  })
  
  # Aggregation je Track
  dataTracks <- reactive({
    df <- dataAll()
    if(nrow(df)==0) return(data.frame())
    df %>%
      group_by(track, album, artists) %>%
      summarise(
        total_views = sum(view_count, na.rm=TRUE),
        n_entries   = n(),
        .groups     = "drop"
      ) %>%
      arrange(track)
  })
  
  # Index für aktuellen Track
  currentIndex <- reactiveVal(1)
  
  # Merker für automatisches Abspielen
  autoPlayEnabled <- reactiveVal(FALSE)
  
  # Liste aller Tracks
  trackList <- reactive({
    dt <- dataTracks()
    if(nrow(dt)==0) return(character())
    dt$track
  })
  
  # Beim ersten Laden direkt zufälligen Track
  observeEvent(dataTracks(), {
    dt <- dataTracks()
    if(nrow(dt) > 0){
      randomI <- sample(seq_len(nrow(dt)), 1)
      currentIndex(randomI)
    }
  }, once=TRUE)
  
  # Aktueller Trackname
  currentTrackName <- reactive({
    allT <- trackList()
    if(length(allT)==0) return("")
    nm <- allT[pmax(1, pmin(currentIndex(), length(allT)))]
    # Originalton verbergen
    if(nm=="Originalton") nm <- ""
    nm
  })
  
  # Aktuelle Zeile
  currentRow <- reactive({
    fullData <- dataAll()
    nm <- currentTrackName()
    if(nm=="") nm <- "Originalton"
    subsetRows <- fullData %>% filter(track == nm)
    if(nrow(subsetRows)==0) return(NULL)
    rid <- sample(seq_len(nrow(subsetRows)), 1)
    subsetRows[rid, ]
  })
  
  # Cover
  output$coverImgUI <- renderUI({
    row <- currentRow()
    if(is.null(row)){
      div(style="width:248px; height:248px; background:#ccc; border-radius:15px;")
    } else {
      splitted <- unlist(strsplit(row$public_links, "\\s+"))
      coverLink <- bildFuerTrack(splitted)
      if(is.null(coverLink)){
        div(style="width:248px; height:248px; background:#ccc; border-radius:15px;")
      } else {
        tags$img(
          src   = coverLink,
          style = "width:248px; height:248px; object-fit:cover; border-radius:15px;"
        )
      }
    }
  })
  
  # ID
  output$entryID <- renderText({
    row <- currentRow()
    if(is.null(row)) return("")
    paste("ID:", row$id)
  })
  
  # Songtitel
  output$songTitle <- renderText({
    currentTrackName()
  })
  
  # Künstler/Album
  output$artistTitle <- renderText({
    dt <- dataTracks()
    nm <- currentTrackName()
    if(nrow(dt)==0 || nm=="") return("(Unknown Artist) - (No Album)")
    row <- dt %>% filter(track==nm)
    if(nrow(row)==0) return("(Unknown Artist) - (No Album)")
    art <- row$artists[1]; if(is.na(art)||art=="") art <- "(Unknown Artist)"
    alb <- row$album[1];  if(is.na(alb)||alb=="") alb <- "(No Album)"
    paste(art, "-", alb)
  })
  
  # Views
  output$viewCountLabel <- renderText({
    dt <- dataTracks()
    nm <- currentTrackName()
    if(nrow(dt)==0 || nm=="") return("Plays: 0")
    row <- dt %>% filter(track==nm)
    if(nrow(row)==0) return("Plays: 0")
    paste("Plays:", row$total_views[1])
  })
  
  # Audio-Logik
  observeEvent(currentRow(), {
    row <- currentRow()
    if(is.null(row)){
      runjs("
        var a=document.getElementById('audioPlayer');
        a.pause();
        a.src='';
      ")
    } else {
      splitted <- unlist(strsplit(row$public_links, "\\s+"))
      au <- audioFuerTrack(splitted)
      runjs(sprintf("
        var a=document.getElementById('audioPlayer');
        a.src='%s';
        var pr=document.getElementById('progressDiv');
        if(pr){pr.style.width='0%%';}
      ", ifelse(is.null(au),"",au)))
      
      if(autoPlayEnabled()){
        runjs("
          var a=document.getElementById('audioPlayer');
          a.play();
        ")
      }
    }
  })
  
  # Buttons
  observeEvent(input$randomTrack, {
    tl <- trackList()
    if(length(tl)==0) return()
    newI <- sample(seq_len(length(tl)), 1)
    currentIndex(newI)
  })
  
  observeEvent(input$nextTrack, {
    tl <- trackList()
    if(length(tl)==0) return()
    idx <- currentIndex()
    idx <- idx + 1
    if(idx > length(tl)) idx <- 1
    currentIndex(idx)
  })
  
  observeEvent(input$prevTrack, {
    tl <- trackList()
    if(length(tl)==0) return()
    idx <- currentIndex()
    idx <- idx - 1
    if(idx < 1) idx <- length(tl)
    currentIndex(idx)
  })
  
  # Play/Pause
  observeEvent(input$playPause, {
    # Aktiviert AutoPlay, wenn Nutzer Audio startet
    runjs("
      var a=document.getElementById('audioPlayer');
      if(a.paused){
        a.play();
        Shiny.setInputValue('forceAutoplay', true);
      } else {
        a.pause();
      }
    ")
  })
  
  observeEvent(input$forceAutoplay, {
    autoPlayEnabled(TRUE)
  })
  
  # Best of
  output$bestOfTable <- renderDT({
    dt <- dataTracks()
    if(nrow(dt)==0) return(datatable(data.frame(Info="Keine Daten")))
    dfBest <- dt %>%
      arrange(desc(total_views)) %>%
      head(100)
    
    datatable(
      dfBest,
      selection="single",
      options=list(pageLength=10),
      rownames=FALSE
    )
  })
  
  observeEvent(input$bestOfTable_rows_selected, {
    dtB <- dataTracks() %>%
      arrange(desc(total_views)) %>%
      head(100)
    sel <- input$bestOfTable_rows_selected
    if(length(sel)>0){
      trName <- dtB$track[sel]
      dtAll  <- dataTracks()
      pos    <- which(dtAll$track==trName)
      if(length(pos)>0) currentIndex(pos[1])
    }
  })
  
  # Top 100
  output$top100table <- renderDT({
    df <- dataAll()
    if(nrow(df)==0) return(datatable(data.frame(Info="Keine Daten")))
    
    dfCount <- df %>%
      filter(track != "Originalton") %>%
      group_by(track) %>%
      summarise(
        n_entries = n(),
        album   = paste(unique(na.omit(album)), collapse=" | "),
        artists = paste(unique(na.omit(artists)), collapse=" | "),
        .groups = 'drop'
      ) %>%
      arrange(desc(n_entries)) %>%
      head(100)
    
    datatable(
      dfCount,
      selection="single",
      options=list(pageLength=10),
      rownames=FALSE
    )
  })
  
  observeEvent(input$top100table_rows_selected, {
    dfCount <- isolate({
      dataAll() %>%
        filter(track != "Originalton") %>%
        group_by(track) %>%
        summarise(n_entries=n(), .groups='drop') %>%
        arrange(desc(n_entries)) %>%
        head(100)
    })
    sel <- input$top100table_rows_selected
    if(length(sel)>0){
      trName <- dfCount$track[sel]
      dtTr   <- dataTracks()
      pos    <- which(dtTr$track==trName)
      if(length(pos)>0) currentIndex(pos[1])
    }
  })
}

cat("==== Starting shinyApp ====\n")
shinyApp(ui, server, options=list(host="0.0.0.0", port=4099, launch.browser=FALSE))
