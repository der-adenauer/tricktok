#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# ==============================================================
# Shiny App mit pagePiling und 5 Seiten:
# 1) Start / Deckblatt
# 2) Einführung (Markdown)
# 3) Fahndungsliste (iFrame)
# 4) Tricktok-Metadaten (PostgreSQL, tabellarisch)
# 5) Info -> Statistiktok (Analysen, Diagramme)
# ==============================================================

# Mehr Logging & Debug in Shiny:
options(shiny.fullstacktrace = TRUE)
options(shiny.error = traceback)
options(shiny.sanitize.errors = FALSE)
options(shiny.trace = TRUE)
options(shiny.reactlog = TRUE)

# Pakete
library(shiny)
library(fullPage)    # pagePiling
library(dplyr)
library(DBI)
library(RPostgres)
library(DT)
library(ggplot2)
library(plotly)
library(scales)
library(stringr)
library(tidyr)
library(lubridate)
library(markdown)
library(bslib)       # navs_pill()

cat("==== START APP SCRIPT ====\n")

# --------------------------------------------------------------------
# 1) Hilfsfunktionen für die Statistiktok-Auswertungen
# --------------------------------------------------------------------

get_total_duration_text <- function(df) {
  total_s <- sum(df$duration, na.rm = TRUE)
  dd   <- total_s %/% (24*3600)
  hh   <- (total_s %% (24*3600)) %/% 3600
  mm   <- (total_s %% 3600) %/% 60
  ss   <- (total_s %% 60)
  paste0(
    "<h2 style='font-weight:bold; font-size:20px;'>Videogesamtdauer</h2>",
    "<p style='font-size:16px; font-weight:bold;'>Sekunden gesamt: ",
      format(total_s, big.mark = ","), "</p>",
    "<p style='font-size:16px; font-weight:bold;'>",
      dd, " Tage, ", hh, " Stunden, ", mm, " Minuten, ", ss, " Sekunden</p>"
  )
}

get_duration_counts <- function(df) {
  df %>%
    filter(!is.na(duration)) %>%
    mutate(duration = as.numeric(duration)) %>%
    count(duration, name="n") %>%
    arrange(duration)
}

get_channel_agg_long <- function(df) {
  df_agg <- df %>%
    group_by(channel, uploader) %>%
    summarise(
      view_count    = sum(view_count, na.rm=TRUE),
      like_count    = sum(like_count, na.rm=TRUE),
      repost_count  = sum(repost_count, na.rm=TRUE),
      comment_count = sum(comment_count, na.rm=TRUE),
      .groups = "drop"
    )
  pivot_longer(
    df_agg,
    cols = c("view_count","like_count","repost_count","comment_count"),
    names_to = "metric", values_to = "value"
  )
}

# Keine separate Funktion mehr für 4 Diagramme;
# wir filtern nach gewählter Metrik (siehe server).
top_50_by_metric <- function(df, metric) {
  df %>%
    filter(metric == metric) %>%
    arrange(desc(value)) %>%
    slice_head(n=50)
}

# Reduziert auf Top 66 (statt 88)
top_66_videos <- function(df, metric) {
  if (! metric %in% c("view_count","like_count","repost_count","comment_count")) {
    metric <- "view_count"
  }
  df_sorted <- df %>% arrange(desc(.data[[metric]]))
  df_top <- head(df_sorted, 66)
  df_top$video_label <- paste0(
    df_top$uploader, " (",
    str_sub(df_top$title, 1, 30),
    if_else(nchar(df_top$title) > 30, "...", ""), ")"
  )
  df_top$video_label <- make.unique(df_top$video_label)
  df_top
}

get_daily_uploads <- function(df) {
  if (!"timestamp" %in% names(df)) {
    message("[get_daily_uploads] Keine 'timestamp'-Spalte!")
    return(NULL)
  }

  # Beispiel: numeric Unix-Sekunden
  df$timestamp <- as.numeric(df$timestamp)
  df$datetime  <- as.POSIXct(df$timestamp, origin="1970-01-01", tz="UTC")

  # Falls 'YYYY-MM-DD HH:MM:SS':
  # df$datetime <- as.POSIXct(df$timestamp, format="%Y-%m-%d %H:%M:%S", tz="UTC")

  df$day  <- floor_date(df$datetime, "day")
  df$year <- year(df$datetime)

  df %>%
    group_by(year, day, uploader, channel_url) %>%
    summarise(count = n(), .groups = "drop")
}

# --------------------------------------------------------------------
# 2) UI mit pagePiling (5 Seiten)
# --------------------------------------------------------------------

ui <- pagePiling(
  sections.color = c("#444444", "#fefefe", "#cccccc", "#d0d0d0", "#f4f4f4"),
  menu = c(
    "Start"        = "section_start",
    "Einführung"   = "section_intro",
    "Fahndung"     = "section_fahndung",
    "Metadaten"    = "section_meta",
    "Info"         = "section_info"
  ),
  # Abstand oben, falls Navigation fixed
  tags$head(
    tags$style(HTML("
      .pp-section {
        padding-top: 80px !important;
      }
    "))
  ),

  # --- Seite 1: Start/Deckblatt ---
  pageSection(
    center = TRUE,
    menu   = "section_start",
    h1("Start-Seite", style="font-size:50px; font-weight:bold; color:white;"),
    h2("Willkommen!", style="color:white;"),
    br(),
    div(
      style="color:white; font-size:18px; max-width:600px;",
      "Dies ist unsere große Shiny-App mit 5 Seiten."
    )
  ),

  # --- Seite 2: Einführung (Markdown) ---
  pageSection(
    center = FALSE,
    menu   = "section_intro",
    h1("Einführung (Markdown)", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      # Pfad zu intro.md anpassen
      includeMarkdown("intro.md")
    )
  ),

  # --- Seite 3: Fahndungsliste (iFrame) ---
  pageSection(
    center = FALSE,
    menu   = "section_fahndung",
    h1("Fahndungsliste", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      # Beispiel-URL anpassen
      tags$iframe(
        src   = "https://example.org/fahndungsliste.html",
        style = "width:100%; height:600px; border:none;"
      )
    )
  ),

  # --- Seite 4: Tricktok-Metadaten (PostgreSQL) ---
  pageSection(
    center = FALSE,
    menu   = "section_meta",
    h1("Tricktok-Metadaten", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      fluidRow(
        column(
          6,
          textInput("search_term", "Suchbegriff (in Title/Desc):", "")
        )
      ),
      br(),
      DTOutput("meta_table")
    )
  ),

  # --- Seite 5: Info -> Statistiktok (Analysen) ---
  pageSection(
    center = FALSE,
    menu   = "section_info",
    h1("Statistiktok (Infos & Diagramme)", style="font-size:30px; font-weight:bold;"),
    fluidPage(
      navs_pill(
        # (A) Veröffentlichungen (Tag/Jahr)
        nav_panel(
          "Veröffentlichungen (Tag/Jahr)",
          fluidPage(
            uiOutput("yearTabs")  # Dynamische Reiter
          )
        ),
        # (B) Videolänge
        nav_panel(
          "Videolänge",
          fluidPage(
            htmlOutput("totalDurationHTML"),
            plotlyOutput("durationPlotShort", height="300px"),
            plotlyOutput("durationPlotLong",  height="300px")
          )
        ),
        # (C) Channel Top 50
        nav_panel(
          "Channels Top 50",
          fluidPage(
            # Radio-Buttons für Views, Likes, Reposts, Comments
            radioButtons("channel_metric", "Metrik wählen:",
              choices = c(
                "Aufrufe (Views)"       = "view_count",
                "Likes (Likes)"         = "like_count",
                "Geteilt (Shares)"      = "repost_count",
                "Kommentare (Comments)" = "comment_count"
              ),
              selected = "view_count",
              inline   = TRUE
            ),
            plotlyOutput("channelsPlotSingle", height="400px")
          )
        ),
        # (D) Top 66 Videos
        nav_panel(
          "Top 66 Videos",
          fluidPage(
            radioButtons("radioMetric", "Metrik wählen:",
              choices = c("Aufrufe (Views)"="view_count",
                          "Likes (Likes)"="like_count",
                          "Geteilt (Shares)"="repost_count",
                          "Kommentare (Comments)"="comment_count"),
              selected = "view_count",
              inline=TRUE
            ),
            plotlyOutput("top66Plot", height="1000px")
          )
        ),
        id = "stat_nav"
      )
    )
  )
)

# --------------------------------------------------------------------
# 3) Server
# --------------------------------------------------------------------

server <- function(input, output, session) {

  # ===========  POSTGRES-VERBINDUNG ===============
  cat("Verbinde zur PostgreSQL-DB...\n")
  con <- dbConnect(
    RPostgres::Postgres(),
    dbname   = Sys.getenv("DB_NAME", "tiktokdb"),
    host     = Sys.getenv("DB_HOST", "188.245.249.154"),
    port     = as.integer(Sys.getenv("DB_PORT", "5432")),
    user     = Sys.getenv("DB_USER", "tiktok_writer"),
    password = Sys.getenv("DB_PASS", "Wr!T3r_92@kLm")
  )

  onSessionEnded(function(){
    message("[Server] Session ended -> close PG connection")
    dbDisconnect(con)
  })

  # ----------------------------------------------------------------
  # (A) Tricktok-Metadaten: alle Zeilen, aber in DataTable paginiert
  # ----------------------------------------------------------------
  meta_data_reactive <- reactive({
    query <- "
      SELECT 
        id, url, title, description, duration, 
        view_count, like_count, repost_count, comment_count,
        uploader, track, album, artists, timestamp, channel, channel_url
      FROM media_metadata
      ORDER BY id DESC
      -- kein LIMIT -> alle Einträge
    "
    df <- dbGetQuery(con, query)
    cat("Metadaten: Anzahl Zeilen =", nrow(df), "\n")

    # Suche
    srch <- input$search_term
    if (!is.null(srch) && nzchar(srch)) {
      srch_low <- tolower(srch)
      df <- df %>%
        filter(
          str_detect(tolower(title), srch_low) |
          str_detect(tolower(description), srch_low)
        )
    }
    df
  })

  output$meta_table <- renderDT({
    datatable(
      meta_data_reactive(),
      options = list(
        pageLength   = 10,
        lengthChange = FALSE, # kein "Show xx entries"
        scrollX      = FALSE
      ),
      class="compact"
    )
  })

  # ----------------------------------------------------------------
  # (B) Statistiktok: ebenfalls alle Einträge
  # ----------------------------------------------------------------
  stats_df <- reactive({
    q2 <- "
      SELECT 
        id, url, title, description, duration, 
        view_count, like_count, repost_count, comment_count,
        uploader, track, album, artists, timestamp, channel, channel_url
      FROM media_metadata
      -- kein LIMIT
    "
    df2 <- dbGetQuery(con, q2)
    cat("Statistik: Anzahl Zeilen =", nrow(df2), "\n")
    df2
  })

  # (B1) Veröffentlichungen (Tag/Jahr)
  output$yearTabs <- renderUI({
    df <- stats_df()
    dcounts <- get_daily_uploads(df)
    validate(need(!is.null(dcounts), "Keine (oder ungeeignete) timestamp-Spalte."))

    df_sums <- dcounts %>%
      group_by(year, day, uploader) %>%
      summarise(count = sum(count), .groups="drop")
    validate(need(nrow(df_sums)>0, "Keine Daten."))

    years <- sort(unique(df_sums$year), decreasing=TRUE)

    # Dynamische Reiter via navs_pill
    tabs <- lapply(years, function(yr){
      outID <- paste0("publishPlot", yr)
      nav_panel(
        title = paste(yr),
        fluidPage(
          plotlyOutput(outID, height="450px")
        )
      )
    })
    navs_pill(!!!tabs)
  })

  observe({
    df <- stats_df()
    dcounts <- get_daily_uploads(df)
    req(dcounts)
    df_sums <- dcounts %>%
      group_by(year, day, uploader) %>%
      summarise(count=n(), .groups="drop")
    req(nrow(df_sums)>0)

    years <- sort(unique(df_sums$year), decreasing=TRUE)
    for (yr in years) {
      local({
        year_local <- yr
        outID      <- paste0("publishPlot", yr)
        output[[outID]] <- renderPlotly({
          sub <- df_sums %>% filter(year == year_local)
          g <- ggplot(sub, aes(x=day, y=count))+
            geom_col(aes(
              fill=uploader,
              text=paste0(
                "Datum: ", day,
                "\nUploader: ", uploader,
                "\nVeröffentlichungen: ", count
              )
            ), position="stack", show.legend=FALSE)+
            labs(
              x="Datum",
              y="Anzahl Veröffentlichungen",
              title=paste("Veröffentlichungen im Jahr", year_local)
            )+
            theme_minimal()+
            theme(
              plot.title = element_text(size=18, face="bold"),
              axis.title = element_text(size=14, face="bold"),
              axis.text  = element_text(size=12, face="bold")
            )
          ggplotly(g, tooltip="text")
        })
      })
    }
  })

  # (B2) Videolänge
  output$totalDurationHTML <- renderUI({
    df <- stats_df()
    HTML(get_total_duration_text(df))
  })
  output$durationPlotShort <- renderPlotly({
    df <- stats_df()
    cts <- get_duration_counts(df)
    short_df <- cts %>% filter(duration <= 90)
    validate(need(nrow(short_df)>0, "Keine Videos <= 90s."))
    g <- ggplot(short_df, aes(x=duration, y=n))+
      geom_col(fill="lightcoral")+
      labs(
        x="Dauer in Sekunden (0–90)",
        y="Anzahl Videos",
        title="Videolänge 0–90s"
      )+
      theme_minimal()+
      theme(
        plot.title=element_text(size=20, face="bold"),
        axis.title=element_text(size=14, face="bold"),
        axis.text=element_text(size=12, face="bold")
      )
    ggplotly(g)
  })
  output$durationPlotLong <- renderPlotly({
    df <- stats_df()
    cts <- get_duration_counts(df)
    long_df <- cts %>% filter(duration>90)
    validate(need(nrow(long_df)>0, "Keine Videos >90s."))
    mx <- max(long_df$duration)
    g <- ggplot(long_df, aes(x=duration, y=n))+
      geom_col(fill="lightcoral")+
      labs(
        x=paste0("Dauer in Sekunden (91–", mx, ")"),
        y="Anzahl Videos",
        title="Videolänge >90s"
      )+
      theme_minimal()+
      theme(
        plot.title=element_text(size=20, face="bold"),
        axis.title=element_text(size=14, face="bold"),
        axis.text=element_text(size=12, face="bold")
      )
    ggplotly(g)
  })

  # (B3) Channels Top 50, aber nur 1 Diagramm je nach gewählter Metrik
  df_channels_long <- reactive({
    # Aggregation in long-Format
    get_channel_agg_long(stats_df())
  })

  output$channelsPlotSingle <- renderPlotly({
    metric <- input$channel_metric
    # top 50
    dd <- df_channels_long()
    sub <- dd %>% 
      filter(metric == metric) %>% 
      arrange(desc(value)) %>% 
      slice_head(n=50)

    # passendes Label
    metric_label <- switch(
      metric,
      "view_count"    = "Aufrufe (Views)",
      "like_count"    = "Likes (Likes)",
      "repost_count"  = "Geteilt (Shares)",
      "comment_count" = "Kommentare (Comments)",
      "???"           = "???"
    )
    # Plot
    sub$channel <- make.unique(as.character(sub$channel))
    sub$channel <- factor(sub$channel, levels=sub$channel)
    g <- ggplot(sub, aes(x=channel, y=value))+
      geom_col(aes(
        fill=channel,
        text=paste0(
          "Channel: ", channel, "\n",
          "Uploader: ", uploader, "\n",
          metric_label, ": ", comma(value)
        )
      ), show.legend=FALSE) +
      scale_y_continuous(labels=label_number(scale=1/1000, suffix="k")) +
      labs(
        x="Channel",
        y=metric_label,
        title=paste("Channels Top 50 -", metric_label)
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size=18, face="bold"),
        axis.title = element_text(size=14, face="bold"),
        axis.text.x=element_text(size=8, face="bold", angle=45, hjust=1),
        axis.text.y=element_text(size=10, face="bold")
      )
    ggplotly(g, tooltip="text")
  })

  # (B4) Top 66 Videos
  output$top66Plot <- renderPlotly({
    df <- stats_df()
    met <- input$radioMetric
    df_top <- top_66_videos(df, met)
    validate(need(nrow(df_top)>0, "Keine Videos vorhanden."))

    df_top <- df_top %>% arrange(desc(.data[[met]]))
    df_top$video_label <- factor(df_top$video_label, levels=rev(df_top$video_label))

    metric_label <- switch(
      met,
      "view_count"    = "Aufrufe (Views)",
      "like_count"    = "Likes (Likes)",
      "repost_count"  = "Geteilt (Shares)",
      "comment_count" = "Kommentare (Comments)"
    )

    g <- ggplot(df_top, aes(x=.data[[met]], y=video_label))+
      geom_col(aes(
        fill=uploader,
        text=paste0(
          "Uploader: ", uploader, "\n",
          "URL: ", url, "\n",
          "Title: ", str_sub(title, 1, 60),
                     if_else(nchar(title)>60, "...", ""), "\n",
          "Dauer: ", duration,"s\n",
          metric_label, ": ", comma(.data[[met]])
        )
      ), alpha=0.7, show.legend=FALSE)+
      scale_x_continuous(labels=label_number(scale=1/1000, suffix="k"))+
      labs(
        x=metric_label,
        y="(Uploader & gekürzter Titel)",
        title=paste("Top 66 -", metric_label)
      )+
      theme_minimal()+
      theme(
        plot.title=element_text(size=20, face="bold"),
        axis.title=element_text(size=14, face="bold"),
        axis.text=element_text(size=12, face="bold")
      )

    ggplotly(g, tooltip="text")
  })
}

# --------------------------------------------------------------------
# 4) ShinyApp starten
# --------------------------------------------------------------------

cat("==== Starting shinyApp ====\n")

shinyApp(
  ui = ui,
  server = server,
  options = list(
    host = "0.0.0.0",
    port = 4040,
    launch.browser = FALSE
  )
)
