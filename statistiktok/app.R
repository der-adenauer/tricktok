library(shiny)
library(DBI)
library(RSQLite)
library(dplyr)
library(ggplot2)
library(plotly)
library(bslib)
library(scales)
library(stringr)
library(tidyr)
library(lubridate)

############################################
# 1) Datenbankverbindung
############################################

db_path <- "filtered_tiktok_media_metadata.db"  # ggf. Pfad anpassen
con <- dbConnect(SQLite(), db_path)

df <- dbReadTable(con, "media_metadata")

dbDisconnect(con)

############################################
# 2) Hilfsfunktionen
############################################

get_total_duration_text <- function(df) {
  total_seconds <- sum(df$duration, na.rm=TRUE)
  days    <- total_seconds %/% (24*3600)
  hours   <- (total_seconds %% (24*3600)) %/% 3600
  minutes <- (total_seconds %% 3600) %/% 60
  seconds <- (total_seconds %% 60)

  paste0(
    "<h2 style='font-weight:bold; font-size:20px;'>Videogesamtdauer</h2>",
    "<p style='font-size:16px; font-weight:bold;'>Sekunden gesamt: ",
      format(total_seconds, big.mark=","), "</p>",
    "<p style='font-size:16px; font-weight:bold;'>",
      days, " Tage, ", hours, " Stunden, ", minutes, " Minuten, ", seconds, " Sekunden</p>"
  )
}

get_duration_counts <- function(df) {
  df %>%
    filter(!is.na(duration)) %>%
    mutate(duration=as.numeric(duration)) %>%
    count(duration, name="n") %>%
    arrange(duration)
}

get_channel_agg_long <- function(df) {
  cols <- c("view_count","like_count","repost_count","comment_count")
  df_agg <- df %>%
    group_by(channel, uploader) %>%
    summarise(
      view_count    = sum(view_count, na.rm=TRUE),
      like_count    = sum(like_count, na.rm=TRUE),
      repost_count  = sum(repost_count, na.rm=TRUE),
      comment_count = sum(comment_count, na.rm=TRUE),
      .groups="drop"
    )

  pivot_longer(df_agg, cols=all_of(cols), names_to="metric", values_to="value")
}

top_50_by_metric <- function(df_long) {
  cols <- c("view_count","like_count","repost_count","comment_count")
  out_list <- lapply(cols, function(m) {
    df_sub <- df_long %>% filter(metric==m)
    df_sub %>% arrange(desc(value)) %>% slice_head(n=50)
  })
  do.call(rbind, out_list)
}

top_88_videos <- function(df, metric) {
  if(! metric %in% c("view_count","like_count","repost_count","comment_count")) {
    metric <- "view_count"
  }
  df_sorted <- df %>% arrange(desc(.data[[metric]]))
  df_top <- head(df_sorted, 88)
  df_top$video_label <- paste0(
    df_top$uploader, " (",
    str_sub(df_top$title, 1, 30),
    if_else(nchar(df_top$title)>30, "...", ""), ")"
  )
  df_top
}

get_daily_uploads <- function(df) {
  if(! "timestamp" %in% names(df)) {
    return(NULL)
  }
  df$datetime <- as.POSIXct(df$timestamp, origin="1970-01-01", tz="UTC")
  df$day  <- floor_date(df$datetime, "day")
  df$year <- year(df$datetime)

  df %>%
    group_by(year, day, uploader, channel_url) %>%
    summarise(count=n(), .groups="drop")
}

############################################
# 3) UI
############################################

ui <- fluidPage(
  tags$head(
    tags$style(HTML("
      .container-fluid {
        max-width: 1200px;
        margin: 0 auto;
      }
    "))
  ),

  titlePanel("Statistiktok"),

  navset_pill(
    # -- TAB A: Veröffentlichungen (Tag/Jahr) mit Unterreiter pro Jahr --
    nav_panel(
      "Veröffentlichungen (Tag/Jahr)",
      fluidPage(
        uiOutput("yearTabs")  # Dynamische Reiter für jedes Jahr
      )
    ),

    # -- TAB 1: Videolänge (0-90 und 91-max) --
    nav_panel(
      "Videolänge",
      fluidPage(
        htmlOutput("totalDurationHTML"),
        plotlyOutput("durationPlotShort", height="300px"),
        plotlyOutput("durationPlotLong",  height="300px")
      )
    ),

    # -- TAB 2: Channels Top 50 --
    nav_panel(
      "Channels Top 50",
      fluidPage(
        h4("Vier Balkendiagramme, je Metrik"),
        plotlyOutput("channelsPlotView",   height="300px"),
        plotlyOutput("channelsPlotLike",   height="300px"),
        plotlyOutput("channelsPlotRepost", height="300px"),
        plotlyOutput("channelsPlotComment",height="300px")
      )
    ),

    # -- TAB 3: Top 88 Videos --
    nav_panel(
      "Top 88 Videos",
      fluidPage(
        radioButtons("radioMetric", "Metrik wählen:",
          choices=c(
            "Aufrufe (Views)"       ="view_count",
            "Likes (Likes)"         ="like_count",
            "Geteilt (Shares)"      ="repost_count",
            "Kommentare (Comments)" ="comment_count"
          ),
          selected="view_count",
          inline=TRUE
        ),
        plotlyOutput("top88Plot", height="1200px")
      )
    ),
    id="main_nav"
  )
)

############################################
# 4) Server
############################################

server <- function(input, output, session) {

  ################################
  # Veröffentlichungen pro Tag/Jahr
  # Dynamische Erzeugung einzelner Reiter
  ################################

  output$yearTabs <- renderUI({
    df_counts <- get_daily_uploads(df)
    validate(need(!is.null(df_counts), "Keine 'timestamp'-Spalte in df."))

    df_sums <- df_counts %>%
      group_by(year, day, uploader) %>%
      summarise(count=sum(count), .groups="drop")

    validate(need(nrow(df_sums)>0, "Keine Daten."))

    years <- sort(unique(df_sums$year), decreasing=TRUE)

    # Pro Jahr ein eigener Reiter
    tabs <- lapply(years, function(yr) {
      plotOutputID <- paste0("publishPlot", yr)
      tabPanel(
        title = paste(yr),
        # Feste Höhe 450px
        plotlyOutput(plotOutputID, height="450px")
      )
    })

    do.call(navset_pill, tabs)
  })

  # Hinterlegt für jedes Jahr renderPlotly
  observe({
    df_counts <- get_daily_uploads(df)
    validate(need(!is.null(df_counts), "Keine 'timestamp'-Spalte in df."))

    df_sums <- df_counts %>%
      group_by(year, day, uploader) %>%
      summarise(count=sum(count), .groups="drop")

    validate(need(nrow(df_sums)>0, "Keine Daten."))

    years <- sort(unique(df_sums$year), decreasing=TRUE)

    for (yr in years) {
      local({
        current_year <- yr
        plotOutputID <- paste0("publishPlot", current_year)

        output[[plotOutputID]] <- renderPlotly({
          df_filtered <- df_sums %>% filter(year == current_year)
          gg <- ggplot(df_filtered, aes(x=day, y=count)) +
            geom_col(
              aes(
                fill=uploader,
                text=paste0(
                  "Datum: ", day, "\n",
                  "Uploader: ", uploader, "\n",
                  "Veröffentlichungen: ", count
                )
              ),
              position="stack",
              show.legend=FALSE
            ) +
            labs(
              x="Datum",
              y="Anzahl Veröffentlichungen",
              title=paste("Veröffentlichungen im Jahr", current_year)
            ) +
            theme_minimal() +
            theme(
              plot.title=element_text(size=18, face="bold"),
              axis.title=element_text(size=14, face="bold"),
              axis.text=element_text(size=12, face="bold")
            )
          ggplotly(gg, tooltip="text")
        })
      })
    }
  })

  ################################
  # Videolänge
  ################################

  output$totalDurationHTML <- renderUI({
    HTML(get_total_duration_text(df))
  })

  output$durationPlotShort <- renderPlotly({
    counts <- get_duration_counts(df)
    short_df <- counts %>% filter(duration <= 90)
    validate(need(nrow(short_df)>0, "Keine Videos <= 90s."))

    gg <- ggplot(short_df, aes(x=duration, y=n)) +
      geom_col(fill="lightcoral") +
      labs(
        x="Dauer in Sekunden (0–90)",
        y="Anzahl Videos",
        title="Videolänge 0–90s"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size=20, face="bold"),
        axis.title = element_text(size=14, face="bold"),
        axis.text  = element_text(size=12, face="bold")
      )

    ggplotly(gg)
  })

  output$durationPlotLong <- renderPlotly({
    counts <- get_duration_counts(df)
    long_df <- counts %>% filter(duration > 90)
    validate(need(nrow(long_df)>0, "Keine Videos > 90s."))

    max_dur <- max(long_df$duration)
    gg <- ggplot(long_df, aes(x=duration, y=n)) +
      geom_col(fill="lightcoral") +
      labs(
        x=paste0("Dauer in Sekunden (91–", max_dur, ")"),
        y="Anzahl Videos",
        title="Videolänge >90s"
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size=20, face="bold"),
        axis.title = element_text(size=14, face="bold"),
        axis.text  = element_text(size=12, face="bold")
      )

    ggplotly(gg)
  })

  ################################
  # Channels Top 50
  ################################

  df_channels_long <- reactive({
    d <- get_channel_agg_long(df)
    top_50_by_metric(d)
  })

  make_channel_barplot <- function(subdata, metric_label) {
    subdata <- subdata %>% arrange(desc(value))
    subdata$channel <- as.character(subdata$channel)
    subdata$channel <- make.unique(subdata$channel)
    subdata$channel <- factor(subdata$channel, levels=subdata$channel)

    gg <- ggplot(subdata, aes(x=channel, y=value)) +
      geom_col(
        aes(
          fill=channel,
          text=paste0(
            "Channel: ", channel, "\n",
            "Uploader: ", uploader, "\n",
            metric_label, ": ", comma(value)
          )
        ),
        show.legend=FALSE
      ) +
      scale_y_continuous(labels=label_number(scale=1/1000, suffix="k")) +
      labs(
        x="Channel",
        y=metric_label,
        title=paste("Channels -", metric_label)
      ) +
      theme_minimal() +
      theme(
        plot.title = element_text(size=20, face="bold"),
        axis.title = element_text(size=14, face="bold"),
        axis.text.x=element_text(size=8, face="bold", angle=45, hjust=1),
        axis.text.y=element_text(size=10, face="bold")
      )

    gg
  }

  output$channelsPlotView <- renderPlotly({
    dd <- df_channels_long()
    sub <- dd %>% filter(metric=="view_count")
    validate(need(nrow(sub)>0, "Keine Daten für Aufrufe (Views)"))
    gg <- make_channel_barplot(sub, "Aufrufe (Views)")
    ggplotly(gg, tooltip="text")
  })

  output$channelsPlotLike <- renderPlotly({
    dd <- df_channels_long()
    sub <- dd %>% filter(metric=="like_count")
    validate(need(nrow(sub)>0, "Keine Daten für Likes (Likes)"))
    gg <- make_channel_barplot(sub, "Likes (Likes)")
    ggplotly(gg, tooltip="text")
  })

  output$channelsPlotRepost <- renderPlotly({
    dd <- df_channels_long()
    sub <- dd %>% filter(metric=="repost_count")
    validate(need(nrow(sub)>0, "Keine Daten für Geteilt (Shares)"))
    gg <- make_channel_barplot(sub, "Geteilt (Shares)")
    ggplotly(gg, tooltip="text")
  })

  output$channelsPlotComment <- renderPlotly({
    dd <- df_channels_long()
    sub <- dd %>% filter(metric=="comment_count")
    validate(need(nrow(sub)>0, "Keine Daten für Kommentare (Comments)"))
    gg <- make_channel_barplot(sub, "Kommentare (Comments)")
    ggplotly(gg, tooltip="text")
  })

  ################################
  # Top 88 Videos
  ################################

  output$top88Plot <- renderPlotly({
    met <- input$radioMetric
    df_top <- top_88_videos(df, met)
    validate(need(nrow(df_top)>0, "Keine Videos vorhanden."))

    # Absteigend, Balken oben = größter Wert
    df_top <- df_top %>% arrange(desc(.data[[met]]))
    df_top$video_label <- as.character(df_top$video_label)
    df_top$video_label <- factor(df_top$video_label, levels=rev(df_top$video_label))

    metric_label <- switch(met,
      "view_count"    = "Aufrufe (Views)",
      "like_count"    = "Likes (Likes)",
      "repost_count"  = "Geteilt (Shares)",
      "comment_count" = "Kommentare (Comments)"
    )

    gg <- ggplot(df_top, aes(x=.data[[met]], y=video_label)) +
      geom_col(
        aes(
          fill=uploader,
          text=paste0(
            "Uploader: ", uploader, "\n",
            "URL: ", url, "\n",
            "Title: ", str_sub(title, 1, 60),
                       if_else(nchar(title)>60, "...", ""), "\n",
            "Dauer: ", duration, "s\n",
            metric_label, ": ", comma(.data[[met]])
          )
        ),
        alpha=0.7,
        show.legend=FALSE
      ) +
      scale_x_continuous(labels=label_number(scale=1/1000, suffix="k")) +
      labs(
        x=metric_label,
        y="(Uploader & gekürzter Titel)",
        title=paste("Top 88 -", metric_label)
      ) +
      theme_minimal() +
      theme(
        plot.title=element_text(size=20, face="bold"),
        axis.title=element_text(size=14, face="bold"),
        axis.text=element_text(size=12, face="bold")
      )

    ggplotly(gg, tooltip="text")
  })
}

shinyApp(
  ui = ui,
  server = server,
  options = list(
    host = "0.0.0.0",
    port = 5010,
    launch.browser = FALSE
  )
)
