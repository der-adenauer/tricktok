#
# Shiny-App (Zeitreihen + Top 100) mit deutschen DataTables-Übersetzungen
# ohne externes CDN. "next" und "previous" sind in Anführungszeichen, um Parser-Konflikte zu vermeiden.
#

library(shiny)
library(bslib)
library(shinyjs)
library(DBI)
library(RPostgres)
library(dplyr)
library(tidyr)
library(echarts4r)
library(shinycssloaders)
library(htmlwidgets)
library(dotenv)
library(pool)
library(DT)

# .env laden (DB-Zugangsdaten)
load_dot_env(".env")

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

# Deutsche Übersetzungen, alle Schlüssel in Anführungszeichen
german_translations <- list(
  "decimal"        = ",",
  "thousands"      = ".",
  "search"         = "Suchen:",
  "lengthMenu"     = "Zeige _MENU_ Einträge",
  "info"           = "Zeige _START_ bis _END_ von _TOTAL_ Einträgen",
  "infoEmpty"      = "Zeige 0 bis 0 von 0 Einträgen",
  "infoFiltered"   = "(gefiltert von _MAX_ Einträgen)",
  "infoPostFix"    = "",
  "loadingRecords" = "Lade...",
  "zeroRecords"    = "Keine passenden Einträge gefunden",
  "emptyTable"     = "Keine Daten in der Tabelle vorhanden",
  "paginate" = list(
    "first"    = "Erste",
    "previous" = "Zurück",
    "next"     = "Weiter",
    "last"     = "Letzte"
  ),
  "aria" = list(
    "sortAscending"  = ": aktivieren, um Spalte aufsteigend zu sortieren",
    "sortDescending" = ": aktivieren, um Spalte absteigend zu sortieren"
  )
)

ui <- fluidPage(
  theme = bs_theme(),
  useShinyjs(),
  
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
      .copy-link-tooltip {
        position: fixed;
        top: 60px;
        right: 20px;
        background-color: rgba(0, 0, 0, 0.8);
        color: white;
        padding: 6px 12px;
        border-radius: 4px;
        font-size: 14px;
        z-index: 9999;
        opacity: 1;
        transition: opacity 0.8s ease;
      }
    "))
  ),
  
  accordion(
    id   = "acc",
    open = "Zeitreihen-Ansicht",
    
    # 1) Zeitreihen-Ansicht
    accordion_panel(
      title = "Zeitreihen-Ansicht",
      icon  = bsicons::bs_icon("bar-chart"),
      
      div(class = "app-container",
          
          # Kopfbereich
          fluidRow(
            column(
              width = 12,
              h4(textOutput("video_uploader_display")),
              h4(textOutput("video_title_display")),
              uiOutput("video_url_display", class = "url-display")
            )
          ),
          
          # Eingaben
          div(class = "input-block",
              fluidRow(
                column(
                  width = 3,
                  textInput(
                    inputId     = "video_id_search",
                    label       = "Video ID Suche:",
                    value       = "",
                    placeholder = "ID hier eingeben ..."
                  ),
                  actionButton("search_id_btn", "Suchen")  # Button unter dem Feld
                ),
                column(
                  width = 3,
                  selectInput(
                    inputId  = "select_uploader",
                    label    = "Uploader:",
                    choices  = NULL,
                    selected = NULL
                  )
                ),
                column(
                  width = 3,
                  selectInput(
                    inputId  = "select_video",
                    label    = "Video (nach Datum sortiert):",
                    choices  = NULL,
                    selected = NULL
                  )
                ),
                column(
                  width = 3,
                  dateRangeInput(
                    inputId = "daterange",
                    label   = "Zeitraum:",
                    start   = Sys.Date() - 7,
                    end     = Sys.Date(),
                    min     = "2000-01-01",
                    max     = Sys.Date() + 1
                  )
                )
              ),
              fluidRow(
                column(
                  width = 12,
                  uiOutput("copy_link_ui")
                )
              )
          ),
          
          fluidRow(
            column(
              width = 12,
              actionButton("zurueck_btn", "Zurück", class = "nav-button"),
              actionButton("weiter_btn", "Weiter", class = "nav-button")
            )
          ),
          
          fluidRow(
            column(
              width = 12,
              withSpinner(
                echarts4rOutput("ts_plot", height = "500px"),
                type = 6
              )
            )
          )
      )
    ),
    
    # 2) Top 100 (Alle Zeiten)
    accordion_panel(
      title = "Top 100 (Alle Zeiten)",
      icon  = bsicons::bs_icon("trophy"),
      
      div(class = "app-container",
          h4("Die Top 100 Videos (nach maximaler View-Anzahl, alle Zeiten):"),
          withSpinner(
            DTOutput("top100_table"),
            type = 6
          ),
          tags$script(HTML("
            $(document).on('click', '.copyLinkBtnTop100', function() {
              var linkToCopy = $(this).attr('data-link');
              if(!linkToCopy) return;
              
              navigator.clipboard.writeText(linkToCopy).then(function() {
                var tooltip = document.createElement('div');
                tooltip.textContent = 'Link kopiert!';
                tooltip.className = 'copy-link-tooltip';
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
          "))
      )
    ),
    
    # 3) Top 100 (14 Tage)
    accordion_panel(
      title = "Top 100 (14 Tage)",
      icon  = bsicons::bs_icon("calendar-date"),
      
      div(class = "app-container",
          h4("Top 100 Videos, die innerhalb der letzten 14 Tage veröffentlicht wurden (max. Views):"),
          withSpinner(
            DTOutput("top100_14_table"),
            type = 6
          ),
          tags$script(HTML("
            $(document).on('click', '.copyLinkBtnTop100_14', function() {
              var linkToCopy = $(this).attr('data-link');
              if(!linkToCopy) return;
              
              navigator.clipboard.writeText(linkToCopy).then(function() {
                var tooltip = document.createElement('div');
                tooltip.textContent = 'Link kopiert!';
                tooltip.className = 'copy-link-tooltip';
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
          "))
      )
    )
  )
)

server <- function(input, output, session) {
  
  current_title    <- reactiveVal("")
  current_uploader <- reactiveVal("")
  current_dburl    <- reactiveVal("")
  
  query_params <- reactiveValues(uploader=NULL, video=NULL, start=NULL, end=NULL)
  
  # 1) URL-Parameter
  observe({
    parsed <- parseQueryString(session$clientData$url_search)
    if (!is.null(parsed$uploader)) query_params$uploader <- parsed$uploader
    if (!is.null(parsed$video))    query_params$video    <- parsed$video
    if (!is.null(parsed$start))    query_params$start    <- parsed$start
    if (!is.null(parsed$end))      query_params$end      <- parsed$end
  })
  
  # 2) Uploader laden
  uploader_data <- dbGetQuery(pool, "
    SELECT DISTINCT uploader
      FROM media_metadata
     WHERE uploader IS NOT NULL
  ORDER BY uploader ASC
  ")
  
  # 3) Uploader select befüllen
  updateSelectInput(session, "select_uploader", choices = uploader_data$uploader)
  
  # 4) Falls ?uploader=...
  observeEvent(uploader_data, {
    if (!is.null(query_params$uploader)) {
      if (query_params$uploader %in% uploader_data$uploader) {
        updateSelectInput(session, "select_uploader", selected = query_params$uploader)
      }
    }
  }, once = TRUE)
  
  video_list <- reactiveVal(data.frame())
  
  # 5) Bei Uploaderwahl => Videos laden
  observeEvent(input$select_uploader, {
    req(input$select_uploader)
    
    sql_videos <- sprintf("
      SELECT id, url, title, timestamp, uploader
        FROM media_metadata
       WHERE uploader = '%s'
    ORDER BY timestamp DESC
    ", input$select_uploader)
    
    vids <- dbGetQuery(pool, sql_videos)
    if (nrow(vids) > 0) {
      time_parsed <- as.POSIXct(as.numeric(vids$timestamp), origin = "1970-01-01")
      label_vec <- paste0(
        vids$id, " (", format(time_parsed, "%Y-%m-%d %H:%M:%S"), ")"
      )
      names(label_vec) <- label_vec
      
      updateSelectInput(session, "select_video", choices=label_vec, selected=label_vec[1])
      
      vids_sorted <- vids %>% mutate(parsed_time = time_parsed) %>% arrange(desc(parsed_time))
      video_list(vids_sorted)
    } else {
      updateSelectInput(session, "select_video", choices=NULL, selected=NULL)
      video_list(data.frame())
    }
  })
  
  # 6) Falls ?video=...
  observeEvent(video_list(), {
    req(nrow(video_list())>0)
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
        if (length(idx)==1) {
          updateSelectInput(session, "select_video", choices=label_vec, selected=label_vec[idx])
        }
      }
    }
  }, ignoreInit=TRUE, once=TRUE)
  
  # 7) Falls ?start=... / ?end=...
  observeEvent(video_list(), {
    if (!is.null(query_params$start) && !is.null(query_params$end)) {
      try_start <- as.Date(query_params$start)
      try_end   <- as.Date(query_params$end)
      if (!is.na(try_start) && !is.na(try_end)) {
        updateDateRangeInput(session, "daterange", start=try_start, end=try_end)
      }
    }
  }, ignoreInit=TRUE, once=TRUE)
  
  # 8) ID-Suche
  observeEvent(input$search_id_btn, {
    req(nchar(input$video_id_search)>0)
    
    sql_meta <- sprintf("
      SELECT id, url, title, timestamp, uploader
        FROM media_metadata
       WHERE id = '%s'
       LIMIT 1
    ", input$video_id_search)
    meta_res <- dbGetQuery(pool, sql_meta)
    
    if (nrow(meta_res)==1) {
      found_upl <- meta_res$uploader[1]
      if (found_upl %in% uploader_data$uploader) {
        updateSelectInput(session, "select_uploader", selected=found_upl)
        
        shinyjs::delay(150, {
          vids <- video_list()
          if (nrow(vids)>0) {
            if (input$video_id_search %in% vids$id) {
              time_parsed <- as.POSIXct(as.numeric(vids$timestamp), origin = "1970-01-01")
              label_vec <- paste0(
                vids$id, " (", format(time_parsed, "%Y-%m-%d %H:%M:%S"), ")"
              )
              names(label_vec) <- label_vec
              
              idx <- which(vids$id == input$video_id_search)
              if (length(idx)==1) {
                updateSelectInput(session, "select_video", choices=label_vec, selected=label_vec[idx])
              }
            }
          }
        })
      }
    }
  }, ignoreInit=TRUE)
  
  # 9) Navigation: Zurück
  observeEvent(input$zurueck_btn, {
    current_data <- video_list()
    if (nrow(current_data)==0) return(NULL)
    
    selected_id <- sub(" .*","",input$select_video)
    idx <- which(current_data$id==selected_id)
    if (length(idx)==0) return(NULL)
    
    new_idx <- idx+1
    if (new_idx>nrow(current_data)) {
      new_idx <- nrow(current_data)
    }
    
    time_parsed <- as.POSIXct(as.numeric(current_data$timestamp), origin="1970-01-01")
    label_vec <- paste0(
      current_data$id," (",format(time_parsed,"%Y-%m-%d %H:%M:%S"),")"
    )
    names(label_vec) <- label_vec
    
    updateSelectInput(session, "select_video", choices=label_vec, selected=label_vec[new_idx])
  })
  
  # 10) Navigation: Weiter
  observeEvent(input$weiter_btn, {
    current_data <- video_list()
    if (nrow(current_data)==0) return(NULL)
    
    selected_id <- sub(" .*","",input$select_video)
    idx <- which(current_data$id==selected_id)
    if (length(idx)==0) return(NULL)
    
    new_idx <- idx-1
    if (new_idx<1) {
      new_idx <- 1
    }
    
    time_parsed <- as.POSIXct(as.numeric(current_data$timestamp), origin="1970-01-01")
    label_vec <- paste0(
      current_data$id," (",format(time_parsed,"%Y-%m-%d %H:%M:%S"),")"
    )
    names(label_vec) <- label_vec
    
    updateSelectInput(session, "select_video", choices=label_vec, selected=label_vec[new_idx])
  })
  
  # 11) Videoauswahl => Metadaten + Datum
  observeEvent(input$select_video, {
    req(input$select_video)
    
    selected_id <- sub(" .*","",input$select_video)
    sql_meta <- sprintf("
      SELECT url, timestamp, title, uploader
        FROM media_metadata
       WHERE id = '%s'
       LIMIT 1
    ", selected_id)
    meta_res <- dbGetQuery(pool, sql_meta)
    if (nrow(meta_res)!=1) return(NULL)
    
    current_title(meta_res$title[1])
    current_uploader(meta_res$uploader[1])
    current_dburl(meta_res$url[1])
    
    creation_unix <- as.numeric(meta_res$timestamp[1])
    creation_dt   <- as.Date(as.POSIXct(creation_unix, origin="1970-01-01"))
    
    sql_max <- sprintf("
      SELECT MAX(recorded_at) AS max_dt
        FROM media_time_series
       WHERE url = '%s'
    ", meta_res$url[1])
    res_max <- dbGetQuery(pool, sql_max)
    
    if (is.na(res_max$max_dt[1])) {
      updateDateRangeInput(session, "daterange", start=creation_dt, end=creation_dt)
    } else {
      last_dt <- as.Date(res_max$max_dt[1])
      if (last_dt<creation_dt) {
        last_dt <- creation_dt
      }
      updateDateRangeInput(session, "daterange", start=creation_dt, end=last_dt)
    }
  })
  
  # 12) Zeitreihen-Plot
  output$ts_plot <- renderEcharts4r({
    req(input$select_video, input$daterange)
    
    start_raw <- input$daterange[1]
    end_raw   <- input$daterange[2]
    
    if (is.na(start_raw) || is.na(end_raw)) {
      start_dt <- Sys.Date()-7
      end_dt   <- Sys.Date()
    } else {
      start_dt <- start_raw
      end_dt   <- end_raw
    }
    
    selected_id <- sub(" .*","",input$select_video)
    sql_meta <- sprintf("
      SELECT url, title, timestamp
        FROM media_metadata
       WHERE id = '%s'
       LIMIT 1
    ", selected_id)
    meta_res <- dbGetQuery(pool, sql_meta)
    req(nrow(meta_res)==1)
    
    video_url     <- meta_res$url[1]
    creation_unix <- as.numeric(meta_res$timestamp[1])
    creation_dt   <- as.POSIXct(creation_unix,origin="1970-01-01")
    
    sql_ts <- sprintf("
      SELECT recorded_at, view_count, like_count, repost_count, comment_count
        FROM media_time_series
       WHERE url = '%s'
         AND recorded_at >= '%s'
         AND recorded_at <= '%s'
    ORDER BY recorded_at ASC
    ",
    video_url,
    format(as.Date(start_dt),"%Y-%m-%d"),
    format(as.Date(end_dt),  "%Y-%m-%d"))
    
    df_ts <- dbGetQuery(pool, sql_ts)
    
    # Dummy-Eintrag: Zeitpunkt Veröffentlichung
    creation_dt_adjusted <- creation_dt
    if (creation_dt < as.Date(start_dt)) {
      creation_dt_adjusted <- as.POSIXct(as.Date(start_dt))
    }
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
    
    if (nrow(df_ts)==0) {
      return(e_charts() %>% e_title("Keine TimeSeries-Daten verfügbar"))
    }
    
    df_long <- df_ts %>%
      pivot_longer(
        cols      = c("view_count","like_count","repost_count","comment_count"),
        names_to  = "metric",
        values_to = "value"
      ) %>% arrange(recorded_at)
    
    df_long %>%
      group_by(metric) %>%
      e_charts(x=recorded_at) %>%
      e_line(serie=value) %>%
      e_tooltip(trigger="axis",backgroundColor="#ffffff",textStyle=list(color="#000000")) %>%
      e_legend(bottom=0) %>%
      e_grid(bottom="15%") %>%
      e_y_axis(
        name = "Wert",
        axisLabel = list(formatter=htmlwidgets::JS("function(value){return Math.round(value);}"))
      ) %>%
      e_x_axis(name="Zeit") %>%
      e_theme("shine") %>%
      e_title(paste("Verlauf Metriken für Video-ID", selected_id))
  })
  
  # 13) Ausgaben: Uploader, Titel, URL
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
      tags$a(href=current_dburl(), current_dburl(), target="_blank")
    )
  })
  
  # 14) Link kopieren
  output$copy_link_ui <- renderUI({
    base_url <- paste0(
      session$clientData$url_protocol,"//",
      session$clientData$url_hostname,
      ifelse(session$clientData$url_port=="","",paste0(":",session$clientData$url_port)),
      session$clientData$url_pathname
    )
    
    selected_uploader <- input$select_uploader
    selected_video_id <- sub(" .*","",input$select_video)
    start_date        <- input$daterange[1]
    end_date          <- input$daterange[2]
    
    if (is.null(selected_uploader) || is.null(selected_video_id) ||
        selected_uploader=="" || selected_video_id=="") {
      return(NULL)
    }
    
    query_string <- paste0(
      "?uploader=",selected_uploader,
      "&video=",   selected_video_id,
      "&start=",   start_date,
      "&end=",     end_date
    )
    full_url <- paste0(base_url, query_string)
    
    tagList(
      tags$button(
        id="copyLinkBtn", class="btn btn-info", "Link kopieren"
      ),
      tags$script(HTML(sprintf("
        (function(){
          var copyBtn = document.getElementById('copyLinkBtn');
          if(!copyBtn) return;
          
          copyBtn.addEventListener('click', function() {
            navigator.clipboard.writeText('%s').then(function() {
              var tooltip = document.createElement('div');
              tooltip.textContent = 'Link kopiert!';
              tooltip.className = 'copy-link-tooltip';
              
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
  
  ###################################################################
  # Top 100 (Alle Zeiten)
  ###################################################################
  
  top100_data <- reactive({
    req(pool)
    sql_top100 <- "
      SELECT m.id,
             m.uploader,
             m.title,
             m.timestamp,
             MAX(t.view_count) AS max_views
        FROM media_metadata m
        JOIN media_time_series t ON m.url = t.url
    GROUP BY m.id, m.uploader, m.title, m.timestamp
    ORDER BY MAX(t.view_count) DESC
       LIMIT 100
    "
    df <- dbGetQuery(pool, sql_top100)
    df <- df %>%
      mutate(
        published_date = as.POSIXct(as.numeric(timestamp), origin="1970-01-01"),
        published_date = format(published_date, "%Y-%m-%d %H:%M:%S")
      )
    df
  })
  
  output$top100_table <- renderDT({
    df_top <- top100_data()
    
    base_url <- paste0(
      session$clientData$url_protocol,"//",
      session$clientData$url_hostname,
      ifelse(session$clientData$url_port=="","",paste0(":",session$clientData$url_port)),
      session$clientData$url_pathname
    )
    
    df_top <- df_top %>%
      mutate(
        copy_link = sprintf(
          "<button class='btn btn-sm btn-primary copyLinkBtnTop100' data-link='%s?uploader=%s&video=%s'>
             Link kopieren
           </button>",
          base_url, uploader, id
        )
      )
    
    datatable(
      df_top %>% select(id,uploader,title,published_date,max_views,copy_link),
      escape   = FALSE,
      rownames = FALSE,
      colnames = c("ID","Uploader","Titel","Veröffentlicht (UTC)","Max. Views","Link"),
      options  = list(
        pageLength = 10,
        autoWidth  = TRUE,
        language   = german_translations
      )
    )
  })
  
  ###################################################################
  # Top 100 (14 Tage)
  ###################################################################
  
  top100_14_data <- reactive({
    req(pool)
    # Nur Videos, deren Timestamp >= (CURRENT_DATE-14) (Epoche)
    sql_14 <- "
      SELECT m.id,
             m.uploader,
             m.title,
             m.timestamp,
             MAX(t.view_count) AS max_views_14d
        FROM media_metadata m
        JOIN media_time_series t ON m.url = t.url
       WHERE m.timestamp >= EXTRACT(EPOCH FROM (CURRENT_DATE - 14))
    GROUP BY m.id, m.uploader, m.title, m.timestamp
    ORDER BY MAX(t.view_count) DESC
       LIMIT 100
    "
    df <- dbGetQuery(pool, sql_14)
    df <- df %>%
      mutate(
        published_date = as.POSIXct(as.numeric(timestamp), origin="1970-01-01"),
        published_date = format(published_date, "%Y-%m-%d %H:%M:%S")
      )
    df
  })
  
  output$top100_14_table <- renderDT({
    df_14 <- top100_14_data()
    
    base_url <- paste0(
      session$clientData$url_protocol,"//",
      session$clientData$url_hostname,
      ifelse(session$clientData$url_port=="","",paste0(":",session$clientData$url_port)),
      session$clientData$url_pathname
    )
    
    df_14 <- df_14 %>%
      mutate(
        copy_link = sprintf(
          "<button class='btn btn-sm btn-success copyLinkBtnTop100_14' data-link='%s?uploader=%s&video=%s'>
             Link kopieren
           </button>",
          base_url, uploader, id
        )
      )
    
    datatable(
      df_14 %>% select(id,uploader,title,published_date,max_views_14d,copy_link),
      escape   = FALSE,
      rownames = FALSE,
      colnames = c("ID","Uploader","Titel","Veröffentlicht (UTC)","Max. Views (14T)","Link"),
      options  = list(
        pageLength = 10,
        autoWidth  = TRUE,
        language   = german_translations
      )
    )
  })
}

cat("==== Starting shinyApp ====\n")
shinyApp(
  ui = ui,
  server = server,
  options = list(host="0.0.0.0", port=4060, launch.browser=FALSE)
)
