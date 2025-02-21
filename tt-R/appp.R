library(shiny)
library(DBI)
library(RPostgres)
library(dplyr)
library(tidyr)
library(echarts4r)
library(htmlwidgets)
library(dotenv)
library(pool)

# .env laden
load_dot_env(".env")

# Pool global initialisieren
pool <- dbPool(
  drv      = Postgres(),
  dbname   = Sys.getenv("DB_NAME"),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASS")
)

onStop(function() {
  poolClose(pool)
})

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .app-container {
        margin-left: 10%;
        margin-right: 10%;
        font-family: Arial, sans-serif;
      }
      h4 {
        color: #333333;
        margin-top: 10px;
        margin-bottom: 5px;
      }
      label {
        font-weight: bold;
      }
      .url-display {
        margin-bottom: 15px;
      }
      .input-block {
        border: 1px solid #ddd;
        padding: 15px;
        border-radius: 6px;
        margin-bottom: 15px;
        background-color: #f9f9f9;
      }
      .nav-button {
        margin-right: 10px;
      }
    "))
  ),
  
  div(class = "app-container",
    # Kopfbereich: Uploader, Titel, URL
    fluidRow(
      column(
        width = 12,
        h4(textOutput("video_uploader_display")),
        h4(textOutput("video_title_display")),
        uiOutput("video_url_display", class = "url-display")
      )
    ),
    
    # Eingabe-Block: alle 4 Felder/Buttons in einer Reihe
    div(class = "input-block",
      fluidRow(
        column(
          width = 3,
          selectInput(
            inputId = "select_uploader",
            label   = "Uploader:",
            choices = NULL,
            selected = NULL
          )
        ),
        column(
          width = 3,
          selectInput(
            inputId = "select_video",
            label   = "Video (nach Datum sortiert):",
            choices = NULL,
            selected = NULL
          )
        ),
        column(
          width = 3,
          dateRangeInput(
            inputId  = "daterange",
            label    = "Erfasster Zeitraum:",
            start    = Sys.Date() - 7,
            end      = Sys.Date(),
            min      = "2000-01-01",
            max      = Sys.Date() + 1
          )
        ),
        column(
          width = 3,
          uiOutput("copy_link_ui")
        )
      )
    ),
    
    # Buttons darunter
    fluidRow(
      column(
        width = 12,
        actionButton("zurueck_btn", "Zurück", class = "nav-button"),
        actionButton("weiter_btn", "Weiter", class = "nav-button")
      )
    ),
    
    # Plot
    fluidRow(
      column(
        width = 12,
        echarts4rOutput("ts_plot", height = "500px")
      )
    )
  )
)

server <- function(input, output, session) {
  current_title    <- reactiveVal("")
  current_uploader <- reactiveVal("")
  current_dburl    <- reactiveVal("")
  
  query_params <- reactiveValues(
    uploader = NULL,
    video    = NULL,
    start    = NULL,
    end      = NULL
  )
  
  # Query-String auslesen
  observe({
    parsed <- parseQueryString(session$clientData$url_search)
    if (!is.null(parsed$uploader)) query_params$uploader <- parsed$uploader
    if (!is.null(parsed$video))    query_params$video    <- parsed$video
    if (!is.null(parsed$start))    query_params$start    <- parsed$start
    if (!is.null(parsed$end))      query_params$end      <- parsed$end
  })
  
  # Uploader abrufen
  uploader_data <- dbGetQuery(pool, "
    SELECT DISTINCT uploader
      FROM media_metadata
     WHERE uploader IS NOT NULL
  ORDER BY uploader ASC
  ")
  
  updateSelectInput(
    session,
    "select_uploader",
    choices = uploader_data$uploader
  )
  
  # Falls Query-Param uploader existiert
  observeEvent(uploader_data, {
    if (!is.null(query_params$uploader)) {
      if (query_params$uploader %in% uploader_data$uploader) {
        updateSelectInput(session, "select_uploader", selected = query_params$uploader)
      }
    }
  }, once = TRUE)
  
  # Reaktive Liste der Videos
  video_list <- reactiveVal(data.frame())
  
  # Bei Auswahl eines Uploaders -> Videos laden
  observeEvent(input$select_uploader, {
    req(input$select_uploader)
    
    query_videos <- sprintf("
      SELECT id, url, title, timestamp, uploader
        FROM media_metadata
       WHERE uploader = '%s'
    ORDER BY timestamp DESC
    ", input$select_uploader)
    
    vids <- dbGetQuery(pool, query_videos)
    if (nrow(vids) > 0) {
      time_parsed <- as.POSIXct(as.numeric(vids$timestamp), origin = "1970-01-01")
      label_vec <- paste0(
        vids$id, " (", format(time_parsed, "%Y-%m-%d %H:%M:%S"), ")"
      )
      names(label_vec) <- label_vec
      
      updateSelectInput(
        session,
        "select_video",
        choices  = label_vec,
        selected = label_vec[1]
      )
      
      videos_sorted <- vids %>%
        mutate(parsed_time = time_parsed) %>%
        arrange(desc(parsed_time))
      video_list(videos_sorted)
    } else {
      updateSelectInput(session, "select_video", choices = NULL, selected = NULL)
      video_list(data.frame())
    }
  })
  
  # Falls Query-Param video
  observeEvent(video_list(), {
    req(nrow(video_list()) > 0)
    if (!is.null(query_params$video)) {
      df <- video_list()
      all_ids <- as.character(df$id)
      if (query_params$video %in% all_ids) {
        time_parsed <- as.POSIXct(as.numeric(df$timestamp), origin = "1970-01-01")
        label_vec <- paste0(
          df$id, " (", format(time_parsed, "%Y-%m-%d %H:%M:%S"), ")"
        )
        names(label_vec) <- label_vec
        
        idx <- which(df$id == query_params$video)
        if (length(idx) == 1) {
          updateSelectInput(session, "select_video", choices = label_vec, selected = label_vec[idx])
        }
      }
    }
  }, ignoreInit = TRUE, once = TRUE)
  
  # Datum aus Query-Param
  observeEvent(video_list(), {
    if (!is.null(query_params$start) && !is.null(query_params$end)) {
      try_start <- as.Date(query_params$start)
      try_end   <- as.Date(query_params$end)
      if (!is.na(try_start) && !is.na(try_end)) {
        updateDateRangeInput(session, "daterange", start = try_start, end = try_end)
      }
    }
  }, ignoreInit = TRUE, once = TRUE)
  
  # Navigation "Zurück"
  observeEvent(input$zurueck_btn, {
    current_data <- video_list()
    if (nrow(current_data) == 0) return(NULL)
    
    selected_id <- sub(" .*", "", input$select_video)
    idx <- which(current_data$id == selected_id)
    if (length(idx) == 0) return(NULL)
    
    new_idx <- idx + 1
    if (new_idx > nrow(current_data)) new_idx <- nrow(current_data)
    
    time_parsed <- as.POSIXct(as.numeric(current_data$timestamp), origin = "1970-01-01")
    label_vec <- paste0(
      current_data$id, " (", format(time_parsed, "%Y-%m-%d %H:%M:%S"), ")"
    )
    names(label_vec) <- label_vec
    
    updateSelectInput(
      session,
      "select_video",
      choices  = label_vec,
      selected = label_vec[new_idx]
    )
  })
  
  # Navigation "Weiter"
  observeEvent(input$weiter_btn, {
    current_data <- video_list()
    if (nrow(current_data) == 0) return(NULL)
    
    selected_id <- sub(" .*", "", input$select_video)
    idx <- which(current_data$id == selected_id)
    if (length(idx) == 0) return(NULL)
    
    new_idx <- idx - 1
    if (new_idx < 1) new_idx <- 1
    
    time_parsed <- as.POSIXct(as.numeric(current_data$timestamp), origin = "1970-01-01")
    label_vec <- paste0(
      current_data$id, " (", format(time_parsed, "%Y-%m-%d %H:%M:%S"), ")"
    )
    names(label_vec) <- label_vec
    
    updateSelectInput(
      session,
      "select_video",
      choices  = label_vec,
      selected = label_vec[new_idx]
    )
  })
  
  # Bei Auswahl Video -> Zeitraum und Meta-Daten anpassen
  observeEvent(input$select_video, {
    req(input$select_video)
    
    selected_id <- sub(" .*", "", input$select_video)
    meta_query <- sprintf("
      SELECT url, timestamp, title, uploader
        FROM media_metadata
       WHERE id = '%s'
       LIMIT 1
    ", selected_id)
    meta_res <- dbGetQuery(pool, meta_query)
    if (nrow(meta_res) != 1) return(NULL)
    
    current_title(meta_res$title[1])
    current_uploader(meta_res$uploader[1])
    current_dburl(meta_res$url[1])
    
    creation_unix <- as.numeric(meta_res$timestamp[1])
    creation_dt   <- as.Date(as.POSIXct(creation_unix, origin = "1970-01-01"))
    
    url_ts_query <- sprintf("
      SELECT MAX(recorded_at) as max_dt
        FROM media_time_series
       WHERE url = '%s'
    ", meta_res$url[1])
    res_max <- dbGetQuery(pool, url_ts_query)
    
    if (is.na(res_max$max_dt[1])) {
      updateDateRangeInput(session, "daterange", start = creation_dt, end = creation_dt)
    } else {
      last_dt <- as.Date(res_max$max_dt[1])
      if (last_dt < creation_dt) {
        last_dt <- creation_dt
      }
      updateDateRangeInput(session, "daterange", start = creation_dt, end = last_dt)
    }
  })
  
  # Plot
  output$ts_plot <- renderEcharts4r({
    req(input$select_video, input$daterange)
    
    start_raw <- input$daterange[1]
    end_raw   <- input$daterange[2]
    if (is.na(start_raw) || is.na(end_raw)) {
      start_dt <- Sys.Date() - 7
      end_dt   <- Sys.Date()
    } else {
      start_dt <- start_raw
      end_dt   <- end_raw
    }
    
    selected_id <- sub(" .*", "", input$select_video)
    meta_query <- sprintf("
      SELECT url, title, timestamp
        FROM media_metadata
       WHERE id = '%s'
       LIMIT 1
    ", selected_id)
    meta_res <- dbGetQuery(pool, meta_query)
    req(nrow(meta_res) == 1)
    
    video_url     <- meta_res$url[1]
    creation_unix <- as.numeric(meta_res$timestamp[1])
    creation_dt   <- as.POSIXct(creation_unix, origin = "1970-01-01")
    
    ts_query <- sprintf("
      SELECT recorded_at, view_count, like_count, repost_count, comment_count
        FROM media_time_series
       WHERE url = '%s'
         AND recorded_at >= '%s'
         AND recorded_at <= '%s'
    ORDER BY recorded_at ASC
    ",
    video_url,
    format(as.Date(start_dt), "%Y-%m-%d"),
    format(as.Date(end_dt),   "%Y-%m-%d"))
    
    df_ts <- dbGetQuery(pool, ts_query)
    
    # Erstellungszeitpunkt als Start
    creation_dt_adjusted <- creation_dt
    if (creation_dt < as.Date(start_dt)) {
      creation_dt_adjusted <- as.POSIXct(as.Date(start_dt))
    }
    
    # Dummy-Eintrag
    if (creation_dt <= as.Date(end_dt)) {
      dummy_row <- data.frame(
        recorded_at   = creation_dt_adjusted,
        view_count    = 0,
        like_count    = 0,
        repost_count  = 0,
        comment_count = 0
      )
      df_ts <- bind_rows(dummy_row, df_ts)
    }
    
    if (nrow(df_ts) == 0) {
      return(e_charts() %>% e_title("Keine TimeSeries-Daten verfügbar"))
    }
    
    df_ts_long <- df_ts %>%
      pivot_longer(
        cols = c("view_count", "like_count", "repost_count", "comment_count"),
        names_to = "metric",
        values_to = "value"
      ) %>%
      arrange(recorded_at)
    
    df_ts_long %>%
      group_by(metric) %>%
      e_charts(x = recorded_at) %>%
      e_line(serie = value) %>%
      e_tooltip(
        trigger         = "axis",
        backgroundColor = "#ffffff",
        textStyle       = list(color = "#000000")
      ) %>%
      e_legend() %>%
      e_y_axis(
        name = "Wert",
        axisLabel = list(
          formatter = htmlwidgets::JS("function(value){return Math.round(value);}")
        )
      ) %>%
      e_x_axis(name = "Zeit") %>%
      e_theme("shine")
  })
  
  # Ausgaben: Uploader, Titel, URL
  output$video_uploader_display <- renderText({
    req(current_uploader())
    paste("Uploader:", current_uploader())
  })
  
  output$video_title_display <- renderText({
    req(current_title())
    paste("Titel:", current_title())
  })
  
  output$video_url_display <- renderUI({
    req(current_dburl())
    tags$div(
      "Datenbank-URL: ",
      tags$a(href = current_dburl(), current_dburl(), target = "_blank")
    )
  })
  
  # Link-kopieren-Button
  output$copy_link_ui <- renderUI({
    base_url <- paste0(
      session$clientData$url_protocol, "//",
      session$clientData$url_hostname,
      ifelse(session$clientData$url_port == "", "", paste0(":", session$clientData$url_port)),
      session$clientData$url_pathname
    )
    
    selected_uploader <- input$select_uploader
    selected_video_id <- sub(" .*", "", input$select_video)
    start_date        <- input$daterange[1]
    end_date          <- input$daterange[2]
    
    if (is.null(selected_uploader) || is.null(selected_video_id) ||
        selected_uploader == "" || selected_video_id == "") {
      return(NULL)
    }
    
    query_string <- paste0(
      "?uploader=", selected_uploader,
      "&video=",    selected_video_id,
      "&start=",    start_date,
      "&end=",      end_date
    )
    full_url <- paste0(base_url, query_string)
    
    tagList(
      tags$button(
        id = "copyLinkBtn",
        class = "btn btn-info",
        "Link kopieren"
      ),
      tags$script(HTML(sprintf("
        (function(){
          var copyBtn = document.getElementById('copyLinkBtn');
          if(!copyBtn) return;
          
          copyBtn.addEventListener('click', function() {
            navigator.clipboard.writeText('%s').then(function() {
              var tooltip = document.createElement('div');
              tooltip.textContent = 'Link kopiert!';
              tooltip.style.position = 'fixed';
              tooltip.style.top = '60px';
              tooltip.style.right = '20px';
              tooltip.style.backgroundColor = 'rgba(0, 0, 0, 0.8)';
              tooltip.style.color = 'white';
              tooltip.style.padding = '6px 12px';
              tooltip.style.borderRadius = '4px';
              tooltip.style.fontSize = '14px';
              tooltip.style.zIndex = '9999';
              tooltip.style.opacity = '1';
              tooltip.style.transition = 'opacity 0.8s ease';
              
              document.body.appendChild(tooltip);
              
              setTimeout(function(){
                tooltip.style.opacity = '0';
                setTimeout(function(){
                  if(tooltip.parentNode) {
                    tooltip.parentNode.removeChild(tooltip);
                  }
                }, 800);
              }, 800);
            });
          });
        })();
      ", full_url)))
    )
  })
}

cat("==== Starting shinyApp ====\n")
shinyApp(
  ui = ui,
  server = server,
  options = list(host = "0.0.0.0", port = 4060, launch.browser = FALSE)
)