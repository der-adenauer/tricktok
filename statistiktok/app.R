# --------------------------------------------------------------
# Pakete
# --------------------------------------------------------------
library(shiny)
library(shinyWidgets)
library(shinybusy)  # Busy-Bar
library(DBI)
library(RPostgres)
library(dplyr)
library(ggplot2)
library(plotly)
library(bslib)
library(scales)
library(stringr)
library(tidyr)
library(lubridate)
library(dotenv)
library(DT)

# --------------------------------------------------------------
# 1) Umgebungsvariablen laden und DB-Verbindung
# --------------------------------------------------------------
load_dot_env(".env")

con <- dbConnect(
  Postgres(),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  dbname   = Sys.getenv("DB_NAME"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASS")
)

df        <- dbReadTable(con, "media_metadata")
df_series <- dbReadTable(con, "media_time_series")
dbDisconnect(con)

df <- df %>% filter(!is.na(uploader))  # Nur Datensätze mit gültigem uploader

# --------------------------------------------------------------
# 2) Hilfsfunktionen
# --------------------------------------------------------------

# Videogesamtdauer berechnen und formatiert ausgeben
get_total_duration_text <- function(df) {
  total_seconds <- sum(df$duration, na.rm = TRUE)
  days    <- total_seconds %/% (24 * 3600)
  hours   <- (total_seconds %% (24 * 3600)) %/% 3600
  minutes <- (total_seconds %% 3600) %/% 60
  seconds <- (total_seconds %% 60)

  paste0(
    "<h2 style='font-weight:bold; font-size:20px;'>Medien-Gesamtdauer im Archiv</h2>",
    "<p style='font-size:16px; font-weight:bold;'>Sekunden gesamt: ",
    format(total_seconds, big.mark = "."), "</p>",
    "<p style='font-size:16px; font-weight:bold;'>",
    days, " Tage, ", hours, " Stunden, ", minutes, " Minuten, ", seconds, " Sekunden</p>"
  )
}

# Häufigkeitsverteilung der Videolänge
get_duration_counts <- function(df) {
  df %>%
    filter(!is.na(duration)) %>%
    mutate(duration = as.numeric(duration)) %>%
    count(duration, name = "n") %>%
    arrange(duration)
}

# Aggregation nach Channel/Uploader (4 Metriken)
get_channel_agg_long <- function(df) {
  cols <- c("view_count", "like_count", "repost_count", "comment_count")
  df_agg <- df %>%
    group_by(channel, uploader) %>%
    summarise(
      view_count    = sum(view_count,    na.rm = TRUE),
      like_count    = sum(like_count,    na.rm = TRUE),
      repost_count  = sum(repost_count,  na.rm = TRUE),
      comment_count = sum(comment_count, na.rm = TRUE),
      .groups = "drop"
    )
  pivot_longer(df_agg, cols = all_of(cols), names_to = "metric", values_to = "value")
}

# Top 50 je Metrik
top_50_by_metric <- function(df_long) {
  cols <- c("view_count", "like_count", "repost_count", "comment_count")
  out_list <- lapply(cols, function(m) {
    df_sub <- df_long %>% filter(metric == m)
    df_sub %>% arrange(desc(value)) %>% slice_head(n = 50)
  })
  do.call(rbind, out_list)
}

# Tages-Aggregat: Anzahl Veröffentlichungen
get_daily_uploads <- function(df) {
  if (!"timestamp" %in% names(df)) {
    return(NULL)
  }
  df$timestamp <- as.numeric(df$timestamp)
  df$datetime  <- as.POSIXct(df$timestamp, origin = "1970-01-01", tz = "UTC")
  df$day       <- floor_date(df$datetime, "day")
  df$year      <- year(df$datetime)

  df %>%
    group_by(year, day, uploader) %>%
    summarise(count = n(), .groups = "drop")
}

# Gelöschte Medien erkennen (keine Aufzeichnung in letzten 12h)
get_deleted_media <- function(df_meta, df_series) {
  if (!all(c("url", "recorded_at") %in% names(df_series))) {
    return(NULL)
  }
  df_series <- df_series %>%
    mutate(recorded_at = as.POSIXct(recorded_at, tz = "UTC"))

  max_ts <- max(df_series$recorded_at, na.rm = TRUE)
  cutoff <- max_ts - hours(12)

  last_record_per_url <- df_series %>%
    group_by(url) %>%
    summarise(last_record = max(recorded_at, na.rm = TRUE), .groups = "drop")

  df_deleted <- last_record_per_url %>%
    filter(last_record < cutoff) %>%
    mutate(deleted_day = floor_date(last_record, "day")) %>%
    left_join(df_meta, by = "url")

  df_deleted
}

# Tages-Aggregation gelöschter Medien
get_deleted_daily <- function(df_del) {
  if (is.null(df_del) || nrow(df_del) == 0) {
    return(NULL)
  }
  df_del %>%
    filter(!is.na(uploader)) %>%
    mutate(deleted_year = year(deleted_day)) %>%
    group_by(deleted_year, deleted_day, uploader) %>%
    summarise(count = n(), .groups = "drop")
}

# --------------------------------------------------------------
# 3) UI
# --------------------------------------------------------------
ui <- fluidPage(
  # Busy-Bar
  add_busy_bar(color = "#F79420", timeout = 500),

  # JS-Code für Kopierfunktion
  tags$head(
    tags$script("
      Shiny.addCustomMessageHandler('copyToClipboard', function(link) {
        navigator.clipboard.writeText(link);
        alert('Link wurde in die Zwischenablage kopiert!');
      });
    "),
    tags$style(HTML("
      .container-fluid {
        max-width: 1200px;
        margin: 0 auto;
      }
      .toggle-legend-btn {
        margin-bottom: 10px;
      }
      .help-text {
        font-size: 14px;
        color: #555;
        margin-top: 10px;
        margin-bottom: 10px;
      }
    "))
  ),

  titlePanel("Statistiktok"),

  actionButton("toggleLegend", "Legende ein-/ausblenden", class = "toggle-legend-btn"),

  navset_pill(
    # -----------------------------------------
    # 1) Veröffentlichungen (Tag/Jahr)
    # -----------------------------------------
    nav_panel(
      "Veröffentlichungen (Tag/Jahr)",
      fluidPage(
        uiOutput("yearTabs")
      )
    ),

    # -----------------------------------------
    # 2) Gelöschte Videos
    # -----------------------------------------
    nav_panel(
      "Gelöschte Videos",
      fluidPage(
        fluidRow(
          column(
            width = 12,
            htmlOutput("deletedInfoText")
          )
        ),
        uiOutput("deletedTabs")
      )
    ),

    # -----------------------------------------
    # 3) Es Veröffentlichungsdicht
    # -----------------------------------------
    nav_panel(
      "Veröffentlichungsdichte",
      fluidPage(
        fluidRow(
          column(
            4,
            # Mehrfachauswahl Uploader mit remove_button-Plugin für kleines X
            selectizeInput(
              "veroeffUploader",
              "Uploader auswählen (Mehrfachauswahl)",
              choices  = sort(unique(df$uploader)),
              selected = sort(unique(df$uploader))[1],
              multiple = TRUE,
              options  = list(plugins = list("remove_button"))  # -> kleines "x" zum Entfernen
            )
          ),
          column(
            4,
            fluidRow(
              column(7,
                dateInput(
                  "veroeffDate",
                  "Datum auswählen",
                  value = Sys.Date(),
                  format = "yyyy-mm-dd"
                )
              ),
              column(5,
                actionButton("btnGenerateLink", "Link teilen", style="margin-top:25px;")
              )
            ),
            fluidRow(
              column(6, actionButton("btnPrevDay", "Vorheriger Tag")),
              column(6, actionButton("btnNextDay", "Nächster Tag"))
            )
          )
        ),
        div(
          class="help-text",
          "Zeigt pro ausgewähltem Uploader die Tageszeit und Aufrufzahl der Postings an. Es werden immer 24 h dargestellt."
        ),
        plotlyOutput("veroeffPlot", height = "400px"),
        htmlOutput("veroeffClickInfo"),
          
        DTOutput("veroeffTable")
      )
    ),

    # -----------------------------------------
    # 4) Videolänge
    # -----------------------------------------
    nav_panel(
      "Videolänge",
      fluidPage(
        htmlOutput("totalDurationHTML"),
        plotlyOutput("durationPlotShort", height = "300px"),
        plotlyOutput("durationPlotLong",  height = "300px")
      )
    ),

    # -----------------------------------------
    # 5) Channels Top 50
    # -----------------------------------------
    nav_panel(
      "Channels Top 50",
      fluidPage(
        h4("Vier Balkendiagramme, je Metrik"),
        plotlyOutput("channelsPlotView",    height = "300px"),
        plotlyOutput("channelsPlotLike",    height = "300px"),
        plotlyOutput("channelsPlotRepost",  height = "300px"),
        plotlyOutput("channelsPlotComment", height = "300px")
      )
    ),

    id = "main_nav"
  )
)

# --------------------------------------------------------------
# 4) Server
# --------------------------------------------------------------
server <- function(input, output, session) {

  # Query-Parameter auswerten
  observeEvent(session$clientData$url_search, once = TRUE, {
    query <- parseQueryString(session$clientData$url_search)
    if(!is.null(query$tab)) {
      updateTabsetPanel(session, "main_nav", selected = query$tab)
    }
    if(!is.null(query$uploader)) {
      # Kommagetrennte Liste in Vektor umwandeln
      upVec <- strsplit(query$uploader, ",")[[1]]
      updateSelectInput(session, "veroeffUploader", selected = upVec)
    }
    if(!is.null(query$date)) {
      parsed_date <- as.Date(query$date)
      if(!is.na(parsed_date)) {
        updateDateInput(session, "veroeffDate", value = parsed_date)
      }
    }
  })

  legendVisible <- reactiveVal(FALSE)
  observeEvent(input$toggleLegend, {
    legendVisible(!legendVisible())
  })

  # --------------------------------------------------------------
  # 1) Veröffentlichungen (Tag/Jahr)
  # --------------------------------------------------------------
  output$yearTabs <- renderUI({
    df_counts <- get_daily_uploads(df)
    validate(need(!is.null(df_counts), "Keine 'timestamp'-Spalte vorhanden."))
    validate(need(nrow(df_counts) > 0, "Keine Daten."))

    years <- sort(unique(df_counts$year), decreasing = TRUE)
    if (length(years) == 0) {
      return(NULL)
    }

    tabs <- lapply(years, function(yr) {
      plotID   <- paste0("publishPlot",  yr)
      labelID  <- paste0("publishLabel", yr)
      tableID  <- paste0("publishTable", yr)

      tabPanel(
        title = paste(yr),
        plotlyOutput(plotID, height = "450px"),
        htmlOutput(labelID),
        DTOutput(tableID)
      )
    })
    do.call(navset_pill, tabs)
  })

  observe({
    df_counts <- get_daily_uploads(df)
    req(df_counts)

    yrs <- sort(unique(df_counts$year), decreasing = TRUE)
    if (length(yrs) == 0) {
      return(NULL)
    }

    # Für jedes Jahr
    for (yr in yrs) {
      local({
        current_year <- yr
        plotID  <- paste0("publishPlot",  yr)
        labelID <- paste0("publishLabel", yr)
        tableID <- paste0("publishTable", yr)

        output[[plotID]] <- renderPlotly({
          df_filtered <- df_counts %>% filter(year == current_year)

          # customdata = "uploader###YYYY-MM-DD"
          gg <- ggplot(df_filtered, aes(x = day, y = count)) +
            geom_col(
              aes(
                fill       = uploader,
                customdata = paste0(uploader, "###", day),
                text       = paste0(
                  "Uploader: ", uploader, "\n",
                  "Datum: ", day, "\n",
                  "Veröffentlichungen: ", count
                )
              ),
              position = "stack",
              show.legend = TRUE
            ) +
            labs(
              x = "Datum",
              y = "Anzahl Veröffentlichungen",
              title = paste("Veröffentlichungen im Jahr", current_year)
            ) +
            theme_minimal() +
            theme(
              plot.title = element_text(size = 18, face = "bold"),
              axis.title = element_text(size = 14, face = "bold"),
              axis.text  = element_text(size = 12, face = "bold")
            )

          p <- ggplotly(gg, source = plotID, tooltip = "text")
          event_register(p, "plotly_click")
          p %>% layout(showlegend = legendVisible())
        })

        observeEvent(event_data("plotly_click", source = plotID), {
          cd <- event_data("plotly_click", source = plotID)
          req(cd$customdata)
          parts <- strsplit(cd$customdata, "###")[[1]]
          if (length(parts) != 2) {
            return(NULL)
          }

          clicked_uploader <- parts[1]
          clicked_day_str   <- parts[2]
          clicked_day       <- as.Date(clicked_day_str)

          output[[labelID]] <- renderUI({
            HTML(sprintf("<h4>Uploader: %s<br/>Tag: %s</h4>", clicked_uploader, clicked_day))
          })

          selected_data <- df %>%
            mutate(
              datetime = as.POSIXct(as.numeric(timestamp), origin = "1970-01-01", tz = "UTC"),
              day      = as.Date(floor_date(datetime, "day"))
            ) %>%
            filter(
              day == clicked_day,
              uploader == clicked_uploader
            ) %>%
            select(
              Datum = datetime,
              id,
              url,
              title,
              timestamp,
              view_count,
              like_count,
              repost_count,
              comment_count
            )

          if (nrow(selected_data) > 0) {
            selected_data <- selected_data %>%
              mutate(
                url = paste0(
                  url,
                  "<br/><a href='", url, "' target='_blank' class='btn btn-primary btn-sm'>Link öffnen</a>"
                )
              )
          }

          output[[tableID]] <- renderDT({
            if (nrow(selected_data) == 0) {
              datatable(
                data.frame(Hinweis = "Keine Einträge gefunden."),
                options = list(dom = "t"),
                rownames = FALSE
              )
            } else {
              datatable(
                selected_data,
                options = list(pageLength = 5),
                rownames = FALSE,
                escape   = FALSE
              )
            }
          })
        })

        # Initialer Hinweis
        output[[labelID]] <- renderUI({
          HTML("<h4>Bitte auf einen Balken klicken.</h4>")
        })
        output[[tableID]] <- renderDT({
          datatable(
            data.frame(Hinweis = "Noch keine Daten ausgewählt."),
            options = list(dom = "t"),
            rownames = FALSE
          )
        })
      })
    }
  })

  # --------------------------------------------------------------
  # 2) Gelöschte Videos
  # --------------------------------------------------------------
  deleted_data <- reactive({
    get_deleted_media(df, df_series)
  })

  output$deletedInfoText <- renderUI({
    df_del <- deleted_data()
    if (is.null(df_del) || nrow(df_del) == 0) {
      return(HTML("<p><strong>Hinweis:</strong> Keine gelöschten Medien oder noch nicht älter als 12 Stunden.</p>"))
    }
    if (!"recorded_at" %in% names(df_series)) {
      return(HTML("<p>Keine 'recorded_at'-Spalte vorhanden.</p>"))
    }

    df_series2 <- df_series %>% mutate(rec = as.POSIXct(recorded_at, tz="UTC"))
    date_min   <- min(df_series2$rec, na.rm = TRUE)
    date_max   <- max(df_series2$rec, na.rm = TRUE)
    n_del      <- nrow(df_del)

    HTML(sprintf("
      <div style='border:1px solid #ccc; padding:10px; margin-bottom:10px; background:#f9f9f9;'>
        <p>
          <strong>Videos gelöscht, temporär deaktiviert oder Kanal auf privat</strong><br/>
          <em>Zeitraum der Zeitreihen-Analyse:</em> %s bis %s<br/>
          <em>Insgesamt:</em> %d gelöschte Medien
        </p>
      </div>
    ",
      format(date_min, "%d.%m.%Y %H:%M"),
      format(date_max, "%d.%m.%Y %H:%M"),
      n_del
    ))
  })

  output$deletedTabs <- renderUI({
    df_del <- deleted_data()
    validate(need(!is.null(df_del), "Keine Daten zu gelöschten Medien."))
    validate(need(nrow(df_del) > 0, "Keine gelöschten Medien gefunden."))

    df_deleted_daily <- get_deleted_daily(df_del)
    validate(need(!is.null(df_deleted_daily), "Keine Daten zu gelöschten Medien."))

    years <- sort(unique(df_deleted_daily$deleted_year), decreasing = TRUE)
    if (length(years) == 0) {
      return(NULL)
    }

    tabs <- lapply(years, function(yr) {
      plotID   <- paste0("deletedPlot",  yr)
      labelID  <- paste0("deletedLabel", yr)
      tableID  <- paste0("deletedTable", yr)

      tabPanel(
        title = paste(yr),
        plotlyOutput(plotID, height = "450px"),
        htmlOutput(labelID),
        DTOutput(tableID)
      )
    })
    do.call(navset_pill, tabs)
  })

  observe({
    df_del <- deleted_data()
    req(df_del)

    df_deleted_daily <- get_deleted_daily(df_del)
    req(df_deleted_daily)

    years <- sort(unique(df_deleted_daily$deleted_year), decreasing = TRUE)
    if (length(years) == 0) {
      return(NULL)
    }

    for (yr in years) {
      local({
        current_year <- yr
        plotID  <- paste0("deletedPlot",  yr)
        labelID <- paste0("deletedLabel", yr)
        tableID <- paste0("deletedTable", yr)

        output[[plotID]] <- renderPlotly({
          df_filtered <- df_deleted_daily %>% filter(deleted_year == current_year)

          # customdata = "uploader###YYYY-MM-DD"
          gg <- ggplot(df_filtered, aes(x = deleted_day, y = count)) +
            geom_col(
              aes(
                fill       = uploader,
                customdata = paste0(uploader, "###", deleted_day),
                text       = paste0(
                  "Uploader: ", uploader, "\n",
                  "Gelöscht am: ", deleted_day, "\n",
                  "Anzahl: ", count
                )
              ),
              position = "stack",
              show.legend = TRUE
            ) +
            labs(
              x = "Tag (letzter Eintrag)",
              y = "Anzahl gelöschter Medien",
              title = paste("Gelöschte Medien im Jahr", current_year)
            ) +
            theme_minimal() +
            theme(
              plot.title = element_text(size = 18, face = "bold"),
              axis.title = element_text(size = 14, face = "bold"),
              axis.text  = element_text(size = 12, face = "bold")
            )

          p <- ggplotly(gg, source = plotID, tooltip = "text")
          event_register(p, "plotly_click")
          p %>% layout(showlegend = legendVisible())
        })

        observeEvent(event_data("plotly_click", source = plotID), {
          cd <- event_data("plotly_click", source = plotID)
          req(cd$customdata)

          parts <- strsplit(cd$customdata, "###")[[1]]
          if (length(parts) != 2) {
            return(NULL)
          }

          clicked_uploader <- parts[1]
          clicked_day_str   <- parts[2]
          clicked_day       <- as.Date(clicked_day_str)

          output[[labelID]] <- renderUI({
            HTML(sprintf("<h4>Uploader: %s<br/>Gelöscht am: %s</h4>",
                         clicked_uploader, clicked_day))
          })

          selected_data <- df_del %>%
            filter(
              uploader == clicked_uploader,
              floor_date(last_record, "day") == clicked_day
            ) %>%
            select(
              id,
              url,
              uploader,
              timestamp,
              title,
              view_count,
              like_count,
              repost_count,
              comment_count,
              last_record
            ) %>%
            mutate(
              veröffentlicht_am = as.POSIXct(as.numeric(timestamp), origin = "1970-01-01", tz = "UTC"),
              gelöscht_am       = last_record
            )

          if (nrow(selected_data) > 0) {
            selected_data <- selected_data %>%
              mutate(
                url = paste0(
                  url,
                  "<br/><a href='", url, "' target='_blank' class='btn btn-primary btn-sm'>Link öffnen</a>"
                )
              )
          }

          output[[tableID]] <- renderDT({
            if (nrow(selected_data) == 0) {
              datatable(
                data.frame(Hinweis = "Keine Einträge gefunden."),
                options = list(dom = "t"),
                rownames = FALSE
              )
            } else {
              datatable(
                selected_data,
                options = list(pageLength = 5),
                rownames = FALSE,
                escape   = FALSE
              )
            }
          })
        })

        # Initial
        output[[labelID]] <- renderUI({
          HTML("<h4>Bitte auf einen Balken klicken.</h4>")
        })
        output[[tableID]] <- renderDT({
          datatable(
            data.frame(Hinweis = "Noch keine Daten ausgewählt."),
            options = list(dom = "t"),
            rownames = FALSE
          )
        })
      })
    }
  })

  # --------------------------------------------------------------
  # 3) Es Veröffentlichungsdicht (Datum, Mehrfachuploader)
  # --------------------------------------------------------------

  observeEvent(input$btnPrevDay, {
    req(input$veroeffDate)
    updateDateInput(session, "veroeffDate", value = as.Date(input$veroeffDate) - 1)
  })
  observeEvent(input$btnNextDay, {
    req(input$veroeffDate)
    updateDateInput(session, "veroeffDate", value = as.Date(input$veroeffDate) + 1)
  })

  veroeff_subdata <- reactive({
    req(input$veroeffUploader, input$veroeffDate)
    df %>%
      mutate(datetime = as.POSIXct(as.numeric(timestamp), origin = "1970-01-01", tz = "UTC")) %>%
      filter(
        uploader %in% input$veroeffUploader,
        as.Date(datetime) == as.Date(input$veroeffDate)
      )
  })

  # Aggregation pro Sekunde und Uploader
  veroeff_agg <- reactive({
    d <- veroeff_subdata()
    if (nrow(d) == 0) {
      return(NULL)
    }
    d %>%
      group_by(uploader, datetime) %>%
      summarise(total_views = sum(view_count, na.rm = TRUE), .groups = "drop")
  })

  output$veroeffPlot <- renderPlotly({
    data_v <- veroeff_agg()
    validate(need(!is.null(data_v) && nrow(data_v) > 0, "Keine Einträge für gewählten Tag/Uploader gefunden."))

    day_start <- as.POSIXct(paste0(as.character(input$veroeffDate), " 00:00:00"), tz = "UTC")
    day_end   <- as.POSIXct(paste0(as.character(input$veroeffDate), " 23:59:59"), tz = "UTC")

    # customdata = "uploader###timestamp"
    gg <- ggplot(
      data_v,
      aes(
        x = datetime,
        y = total_views,
        fill = uploader,
        customdata = paste0(uploader, "###", as.numeric(datetime)),
        text = paste0(
          "Uploader: ", uploader, "\n",
          "Zeit: ", format(datetime, "%Y-%m-%d %H:%M:%S"), "\n",
          "Aufrufe (Summe): ", total_views
        )
      )
    ) +
      geom_col(position = "stack") +
      scale_x_datetime(
        limits = c(day_start, day_end),
        date_breaks = "2 hours",
        date_labels = "%H:%M",
        name = "Uhrzeit"
      ) +
      scale_y_continuous(
        name = "Aufrufe",
        labels = label_number(scale = 1/1000, suffix = "K", big.mark = ".", decimal.mark = ",")
      ) +
      labs(title = "Veröffentlichungsdichte nach Uploader") +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 18, face = "bold")
      )

    p <- ggplotly(gg, source = "veroeffPlot", tooltip = "text")
    event_register(p, "plotly_click")
    p %>% layout(showlegend = legendVisible())
  })

  observeEvent(event_data("plotly_click", source = "veroeffPlot"), {
    cd <- event_data("plotly_click", source = "veroeffPlot")
    req(cd$customdata)

    parts <- strsplit(cd$customdata, "###")[[1]]
    if (length(parts) != 2) {
      return(NULL)
    }

    clicked_uploader <- parts[1]
    clicked_num      <- as.numeric(parts[2])
    clicked_dt       <- as.POSIXct(clicked_num, origin = "1970-01-01", tz = "UTC")

    output$veroeffClickInfo <- renderUI({
      HTML(sprintf("<h4>Uploader: %s<br/>Zeitpunkt: %s</h4>",
                   clicked_uploader, format(clicked_dt, "%Y-%m-%d %H:%M:%S")))
    })

    sdata <- veroeff_subdata() %>%
      filter(
        uploader == clicked_uploader,
        abs(as.numeric(datetime) - clicked_num) < 1
      ) %>%
      mutate(
        url = paste0(
          url,
          "<br/><a href='", url, "' target='_blank' class='btn btn-primary btn-sm'>Link öffnen</a>"
        )
      ) %>%
      select(
        id,
        url,
        title,
        view_count,
        like_count,
        repost_count,
        comment_count,
        datetime
      )

    output$veroeffTable <- renderDT({
      if (nrow(sdata) == 0) {
        datatable(
          data.frame(Hinweis = "Keine Einträge gefunden."),
          options = list(dom = "t"),
          rownames = FALSE
        )
      } else {
        datatable(
          sdata,
          options = list(pageLength = 5),
          rownames = FALSE,
          escape   = FALSE
        )
      }
    })
  })

  output$veroeffClickInfo <- renderUI({
    HTML("<h4>Bitte auf einen Teilbalken klicken.</h4>")
  })
  output$veroeffTable <- renderDT({
    datatable(
      data.frame(Hinweis = "Noch keine Daten ausgewählt."),
      options = list(dom = "t"),
      rownames = FALSE
    )
  })

  # Link-Funktion
  observeEvent(input$btnGenerateLink, {
    baseUrl <- paste0(
      session$clientData$url_protocol,
      "//",
      session$clientData$url_hostname,
      ifelse(
        session$clientData$url_port == "" || is.na(session$clientData$url_port),
        "",
        paste0(":", session$clientData$url_port)
      ),
      session$clientData$url_pathname
    )
    shareTab  <- "Es+Veröffentlichungsdicht"
    shareUpl  <- URLencode(paste(input$veroeffUploader, collapse = ","), reserved = TRUE)
    shareDate <- as.character(input$veroeffDate)

    newQueryString <- paste0(
      "?tab=", shareTab,
      "&uploader=", shareUpl,
      "&date=",    shareDate
    )

    finalLink <- paste0(baseUrl, newQueryString)
    session$sendCustomMessage("copyToClipboard", finalLink)
  })

  # --------------------------------------------------------------
  # 4) Videolänge
  # --------------------------------------------------------------
  output$totalDurationHTML <- renderUI({
    HTML(get_total_duration_text(df))
  })

  output$durationPlotShort <- renderPlotly({
    counts <- get_duration_counts(df)
    short_df <- counts %>% filter(duration <= 90)
    validate(need(nrow(short_df) > 0, "Keine Videos <= 90s gefunden."))

    gg <- ggplot(short_df, aes(x = duration, y = n)) +
      geom_col(fill = "lightcoral") +
      scale_y_continuous(
        labels = label_number(scale = 1/1000, suffix = "K", big.mark = ".", decimal.mark = ",")
      ) +
      labs(
        x = "Dauer (0–90s)",
        y = "Anzahl Videos",
        title = "Videolänge 0–90s"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 20, face = "bold"),
        axis.title = element_text(size = 14, face = "bold"),
        axis.text  = element_text(size = 12, face = "bold")
      )

    p <- ggplotly(gg, tooltip = "y")
    event_register(p, "plotly_click")
    p %>% layout(showlegend = legendVisible())
  })

  output$durationPlotLong <- renderPlotly({
    counts <- get_duration_counts(df)
    long_df <- counts %>% filter(duration > 90)
    validate(need(nrow(long_df) > 0, "Keine Videos > 90s gefunden."))

    max_dur <- max(long_df$duration, na.rm = TRUE)
    gg <- ggplot(long_df, aes(x = duration, y = n)) +
      geom_col(fill = "lightcoral") +
      scale_y_continuous(
        labels = label_number(scale = 1/1000, suffix = "K", big.mark = ".", decimal.mark = ",")
      ) +
      labs(
        x = paste0("Dauer (91–", max_dur, "s)"),
        y = "Anzahl Videos",
        title = "Videolänge >90s"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size = 20, face = "bold"),
        axis.title = element_text(size = 14, face = "bold"),
        axis.text  = element_text(size = 12, face = "bold")
      )

    p <- ggplotly(gg, tooltip = "y")
    event_register(p, "plotly_click")
    p %>% layout(showlegend = legendVisible())
  })

  # --------------------------------------------------------------
  # 5) Channels Top 50
  # --------------------------------------------------------------
  df_channels_long <- reactive({
    d <- get_channel_agg_long(df)
    top_50_by_metric(d)
  })

  make_channel_barplot <- function(subdata, metric_label) {
    subdata <- subdata %>% arrange(desc(value))
    subdata$channel <- as.character(subdata$channel)
    subdata$channel <- make.unique(subdata$channel)
    subdata$channel <- factor(subdata$channel, levels = subdata$channel)

    gg <- ggplot(subdata, aes(x = channel, y = value)) +
      geom_col(
        aes(
          fill = channel,
          text = paste0(
            "Channel: ", channel, "\n",
            "Uploader: ", uploader, "\n",
            metric_label, ": ", value
          )
        ),
        show.legend = TRUE
      ) +
      scale_y_continuous(
        labels = label_number(scale = 1/1000, suffix = "K", big.mark = ".", decimal.mark = ",")
      ) +
      labs(
        x = "Channel",
        y = metric_label,
        title = paste("Channels -", metric_label)
      ) +
      theme_minimal() +
      theme(
        plot.title  = element_text(size = 20, face = "bold"),
        axis.title  = element_text(size = 14, face = "bold"),
        axis.text.x = element_text(size = 8,  face = "bold", angle = 45, hjust = 1),
        axis.text.y = element_text(size = 10, face = "bold")
      )
    gg
  }

  output$channelsPlotView <- renderPlotly({
    dd <- df_channels_long()
    sub <- dd %>% filter(metric == "view_count")
    validate(need(nrow(sub) > 0, "Keine Daten für Aufrufe (Views)."))
    gg <- make_channel_barplot(sub, "Aufrufe")
    p <- ggplotly(gg, tooltip = "text")
    event_register(p, "plotly_click")
    p %>% layout(showlegend = legendVisible())
  })

  output$channelsPlotLike <- renderPlotly({
    dd <- df_channels_long()
    sub <- dd %>% filter(metric == "like_count")
    validate(need(nrow(sub) > 0, "Keine Daten für Likes."))
    gg <- make_channel_barplot(sub, "Likes")
    p <- ggplotly(gg, tooltip = "text")
    event_register(p, "plotly_click")
    p %>% layout(showlegend = legendVisible())
  })

  output$channelsPlotRepost <- renderPlotly({
    dd <- df_channels_long()
    sub <- dd %>% filter(metric == "repost_count")
    validate(need(nrow(sub) > 0, "Keine Daten für Reposts."))
    gg <- make_channel_barplot(sub, "Geteilt (Shares)")
    p <- ggplotly(gg, tooltip = "text")
    event_register(p, "plotly_click")
    p %>% layout(showlegend = legendVisible())
  })

  output$channelsPlotComment <- renderPlotly({
    dd <- df_channels_long()
    sub <- dd %>% filter(metric == "comment_count")
    validate(need(nrow(sub) > 0, "Keine Daten für Kommentare."))
    gg <- make_channel_barplot(sub, "Kommentare")
    p <- ggplotly(gg, tooltip = "text")
    event_register(p, "plotly_click")
    p %>% layout(showlegend = legendVisible())
  })
}

# --------------------------------------------------------------
# Shiny-App starten
# --------------------------------------------------------------
shinyApp(
  ui = ui,
  server = server,
  options = list(
    host = "0.0.0.0",
    port = 5010,
    launch.browser = FALSE
  )
)
