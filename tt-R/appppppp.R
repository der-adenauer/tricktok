###########################################################
# Pakete
###########################################################
library(shiny)
library(shinyWidgets)
library(shinybusy)      # Für Busy-Bar oben
library(bslib)
library(DBI)
library(RPostgres)
library(dplyr)
library(lubridate)
library(dotenv)
library(readr)

###########################################################
# Datenbank-Verbindung & Ladedaten
###########################################################
load_dot_env(".env")

con <- dbConnect(
  Postgres(),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  dbname   = Sys.getenv("DB_NAME"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASS")
)
df <- dbReadTable(con, "media_metadata")
dbDisconnect(con)

###########################################################
# Lokale CSV für Agenten-Daten
###########################################################
csv_file_path <- "agenten_data.csv"

if (file.exists(csv_file_path)) {
  agenten_data_df <- read_csv(csv_file_path, show_col_types = FALSE)

  # Alte Spalten ggf. entfernen oder umbennen
  # Wir brauchen nun: channel, uploader, manipulationsmuster, specific_strategies, notes, delete_order, official_political, suspicion_case, natural_person
  if (!"uploader" %in% names(agenten_data_df)) {
    agenten_data_df$uploader <- ""
  }
  if (!"specific_strategies" %in% names(agenten_data_df)) {
    agenten_data_df$specific_strategies <- ""
  }
  if (!"official_political" %in% names(agenten_data_df)) {
    agenten_data_df$official_political <- FALSE
  }
  if (!"suspicion_case" %in% names(agenten_data_df)) {
    agenten_data_df$suspicion_case <- FALSE
  }
  if (!"delete_order" %in% names(agenten_data_df)) {
    agenten_data_df$delete_order <- FALSE
  }
  if (!"natural_person" %in% names(agenten_data_df)) {
    agenten_data_df$natural_person <- FALSE
  }

  # foreign_influence existierte vorher => ggf. entfernen, falls noch vorhanden
  if ("foreign_influence" %in% names(agenten_data_df)) {
    agenten_data_df$foreign_influence <- NULL
  }

} else {
  # Neue CSV-Struktur
  agenten_data_df <- data.frame(
    channel             = character(),
    uploader            = character(),   # NEU
    manipulationsmuster = character(),
    specific_strategies = character(),
    notes               = character(),
    delete_order        = logical(),
    official_political  = logical(),
    suspicion_case      = logical(),
    natural_person      = logical(),     # NEU
    stringsAsFactors    = FALSE
  )
}

###########################################################
# Hilfsfunktionen
###########################################################
chunk_to_rows <- function(ui_list, chunk_size = 3) {
  rows <- list()
  seq_starts <- seq(1, length(ui_list), by = chunk_size)
  for (start in seq_starts) {
    end <- min(start + chunk_size - 1, length(ui_list))
    row_elems <- ui_list[start:end]
    rows[[length(rows) + 1]] <- fluidRow(row_elems)
  }
  do.call(tagList, rows)
}

# Global-Aggregation
get_global_aggregation <- function(data_all) {
  data_all <- data_all %>%
    mutate(
      timestamp_num = as.numeric(timestamp),
      dt = as.POSIXct(timestamp_num, origin = "1970-01-01", tz = "UTC")
    )

  df_all_agg <- data_all %>%
    group_by(channel) %>%
    summarise(
      total_count    = n(),
      total_views    = sum(view_count,    na.rm = TRUE),
      total_likes    = sum(like_count,    na.rm = TRUE),
      total_comments = sum(comment_count, na.rm = TRUE),
      total_reposts  = sum(repost_count,  na.rm = TRUE),
      earliest_ts    = min(timestamp_num, na.rm = TRUE),
      latest_ts      = max(timestamp_num, na.rm = TRUE),
      channel_id     = if ("channel_id" %in% names(data_all)) first(channel_id) else NA,
      .groups = "drop"
    ) %>%
    mutate(
      first_video_date = as.POSIXct(earliest_ts, origin = "1970-01-01", tz = "UTC"),
      last_video_date  = as.POSIXct(latest_ts,   origin = "1970-01-01", tz = "UTC")
    )

  # Erster Uploader aus dem DB-Feld
  df_earliest_uploaders <- data_all %>%
    group_by(channel) %>%
    slice_min(timestamp_num, with_ties = FALSE) %>%
    ungroup() %>%
    select(channel, first_uploader = uploader)

  df_all_agg <- df_all_agg %>%
    left_join(df_earliest_uploaders, by = "channel")

  df_all_agg
}

# Range-Aggregation
get_range_aggregation <- function(data_range) {
  data_range %>%
    group_by(channel) %>%
    summarise(
      range_count = n(),
      .groups = "drop"
    )
}

###########################################################
# UI
###########################################################
ui <- fluidPage(

  # Busy-Bar
  add_busy_bar(color="#FF0000"),

  # Sticky-Bereich für globalen Speicherbutton
  tags$style("
    #global_save_btn_fixed {
      position: fixed;
      top: 70px;
      right: 20px;
      z-index: 9999;
      display: none; 
      border:1px solid #ccc;
      background:#f9f9f9;
      padding:10px;
      border-radius:5px;
    }
  "),

  navbarPage(
    title = "propaganda kanäle",

    header = tagList(
      tags$style("
        .navbar .navbar-nav { float:left; margin-left:10px; }
        .navbar .form-inline { float:right; margin-right:15px; }
      "),
      div(
        style = "padding:6px 15px;",
        HTML("<strong>Sortiert nach:</strong> Veröffentlichungen, Views, Likes, Comments, Reposts")
      ),
      div(
        class = "form-inline",
        style = "padding-top:8px; margin-right:15px;",
        dateRangeInput(
          "date_range",
          label = NULL,
          start = as.Date("2025-01-01"),
          end   = Sys.Date(),
          min   = as.Date("2000-01-01"),
          max   = Sys.Date(),
          format="dd.mm.yyyy",
          language="de",
          separator=" - "
        ),
        actionButton("updateChannels", "Aktualisieren")
      ),
      div(
        class="form-inline",
        style="padding-top:8px; margin-right:15px;",
        materialSwitch(
          inputId="agent_switch",
          label="Agentenmodus",
          value=FALSE,
          status="danger"
        )
      )
    ),

    tabPanel("Veröffentlichungen", fluidPage(
      uiOutput("selected_date_range_text_veroeff"),
      uiOutput("pagi_veroeff_top"),
      uiOutput("cards_veroeffentlichungen"),
      uiOutput("pagi_veroeff_bottom")
    )),
    tabPanel("Views", fluidPage(
      uiOutput("selected_date_range_text_views"),
      uiOutput("pagi_views_top"),
      uiOutput("cards_views"),
      uiOutput("pagi_views_bottom")
    )),
    tabPanel("Likes", fluidPage(
      uiOutput("selected_date_range_text_likes"),
      uiOutput("pagi_likes_top"),
      uiOutput("cards_likes"),
      uiOutput("pagi_likes_bottom")
    )),
    tabPanel("Comments", fluidPage(
      uiOutput("selected_date_range_text_comments"),
      uiOutput("pagi_comments_top"),
      uiOutput("cards_comments"),
      uiOutput("pagi_comments_bottom")
    )),
    tabPanel("Reposts", fluidPage(
      uiOutput("selected_date_range_text_posts"),
      uiOutput("pagi_reposts_top"),
      uiOutput("cards_reposts"),
      uiOutput("pagi_reposts_bottom")
    ))
  ),

  uiOutput("global_save_btn_fixed")
)

###########################################################
# SERVER
###########################################################
server <- function(input, output, session) {

  # Reactive boolean: Agentenmodus an/aus
  agentenmodus <- reactiveVal(FALSE)

  # Sticky globaler Button
  output$global_save_btn_fixed <- renderUI({
    if(!agentenmodus()) {
      tags$div(id="global_save_btn_fixed", style="display:none;")
    } else {
      tags$div(
        id="global_save_btn_fixed",
        style="display:block;",
        # Gleiche Farbe wie "Steckbrief kopieren" => btn-primary
        actionButton("global_save_btn","Alle Änderungen speichern", class="btn btn-primary")
      )
    }
  })

  # Agentenmodus-Passwort
  observeEvent(input$agent_switch, {
    if(input$agent_switch) {
      showModal(
        modalDialog(
          title="Agentenmodus aktivieren",
          textInput("agent_password","Passwort eingeben:"),
          footer=tagList(
            modalButton("Abbrechen"),
            actionButton("confirm_agent","Bestätigen")
          )
        )
      )
    } else {
      agentenmodus(FALSE)
    }
  })

  observeEvent(input$confirm_agent, {
    req(input$agent_password)
    if(input$agent_password=="1234") {
      agentenmodus(TRUE)
      removeModal()
    } else {
      showNotification("Falsches Passwort!", type="error")
      updateMaterialSwitch(session,"agent_switch",value=FALSE)
    }
  })

  # Daten + Aggregationen
  filtered_data <- reactiveVal(NULL)
  df_all_agg    <- get_global_aggregation(df)

  # Merge + Sort
  merge_and_sort <- function(metric_name){
    dat <- filtered_data()
    if(is.null(dat)||nrow(dat)==0) return(data.frame())
    df_range_agg <- get_range_aggregation(dat)
    if(nrow(df_range_agg)==0) return(data.frame())

    df_joined <- df_all_agg %>%
      inner_join(df_range_agg, by="channel")
    if(nrow(df_joined)==0) return(data.frame())

    if(metric_name=="veroeffentlichungen") {
      df_joined <- df_joined %>% arrange(desc(range_count))
    } else if(metric_name=="views") {
      df_joined <- df_joined %>% arrange(desc(total_views))
    } else if(metric_name=="likes") {
      df_joined <- df_joined %>% arrange(desc(total_likes))
    } else if(metric_name=="comments") {
      df_joined <- df_joined %>% arrange(desc(total_comments))
    } else if(metric_name=="reposts") {
      df_joined <- df_joined %>% arrange(desc(total_reposts))
    }
    df_joined
  }

  # Pagination
  page_size       <- 99
  veroeff_page    <- reactiveVal(1)
  views_page      <- reactiveVal(1)
  likes_page      <- reactiveVal(1)
  comments_page   <- reactiveVal(1)
  reposts_page    <- reactiveVal(1)

  make_pagination_ui <- function(metric, position){
    renderUI({
      df_all <- merge_and_sort(metric)
      if(nrow(df_all)==0) return(NULL)

      current_page <- if(metric=="veroeffentlichungen") veroeff_page() else
                      if(metric=="views") views_page() else
                      if(metric=="likes") likes_page() else
                      if(metric=="comments") comments_page() else
                      if(metric=="reposts") reposts_page()

      total_pages <- ceiling(nrow(df_all)/page_size)
      if(total_pages<2) return(NULL)

      fluidRow(
        column(6,
          if(current_page>1) {
            actionButton(paste0("prev_",metric,"_",position),"<< Vorherige Seite")
          }
        ),
        column(6, style="text-align:right;",
          span(paste0("Seite ",current_page," von ",total_pages), style="margin-right:10px;"),
          if(current_page<total_pages) {
            actionButton(paste0("next_",metric,"_",position),"Nächste Seite >>")
          }
        )
      )
    })
  }

  # RenderUI (Pagination) pro Tab
  output$pagi_veroeff_top    <- make_pagination_ui("veroeffentlichungen","top")
  output$pagi_veroeff_bottom <- make_pagination_ui("veroeffentlichungen","bottom")
  output$pagi_views_top      <- make_pagination_ui("views","top")
  output$pagi_views_bottom   <- make_pagination_ui("views","bottom")
  output$pagi_likes_top      <- make_pagination_ui("likes","top")
  output$pagi_likes_bottom   <- make_pagination_ui("likes","bottom")
  output$pagi_comments_top   <- make_pagination_ui("comments","top")
  output$pagi_comments_bottom<- make_pagination_ui("comments","bottom")
  output$pagi_reposts_top    <- make_pagination_ui("reposts","top")
  output$pagi_reposts_bottom <- make_pagination_ui("reposts","bottom")

  # Prev/Next - veroeffentlichungen
  observeEvent(input$prev_veroeffentlichungen_top,{
    p <- veroeff_page(); if(p>1) veroeff_page(p-1)
  })
  observeEvent(input$prev_veroeffentlichungen_bottom,{
    p <- veroeff_page(); if(p>1) veroeff_page(p-1)
  })
  observeEvent(input$next_veroeffentlichungen_top,{
    dtmp <- merge_and_sort("veroeffentlichungen")
    tp <- ceiling(nrow(dtmp)/page_size)
    p  <- veroeff_page()
    if(p<tp) veroeff_page(p+1)
  })
  observeEvent(input$next_veroeffentlichungen_bottom,{
    dtmp <- merge_and_sort("veroeffentlichungen")
    tp <- ceiling(nrow(dtmp)/page_size)
    p  <- veroeff_page()
    if(p<tp) veroeff_page(p+1)
  })

  # (Analog: Pagination events für views, likes, comments, reposts ...)
  # aus Platzgründen hier weggelassen

  # Filter
  observeEvent(input$updateChannels, {
    req(input$date_range)
    start_date <- as.POSIXct(input$date_range[1])
    end_date   <- as.POSIXct(input$date_range[2]) + 86399

    df_in_range <- df %>%
      mutate(
        timestamp_num = as.numeric(timestamp),
        datetime=as.POSIXct(timestamp_num, origin="1970-01-01", tz="UTC")
      ) %>%
      filter(datetime>=start_date, datetime<=end_date)

    filtered_data(df_in_range)
    veroeff_page(1); views_page(1); likes_page(1); comments_page(1); reposts_page(1)
  })

  # Init
  observe({
    if(is.null(filtered_data())){
      start_date <- as.POSIXct("2025-01-01")
      end_date   <- as.POSIXct(Sys.Date()) + 86399

      df_in_range <- df %>%
        mutate(
          timestamp_num = as.numeric(timestamp),
          datetime=as.POSIXct(timestamp_num, origin="1970-01-01", tz="UTC")
        ) %>%
        filter(datetime>=start_date, datetime<=end_date)

      filtered_data(df_in_range)
    }
  })

  # Anzeige gewählter Zeitraum
  make_date_range_text <- function(tab) {
    renderUI({
      req(input$date_range)
      sd <- format(as.Date(input$date_range[1]), "%d.%m.%Y")
      ed <- format(as.Date(input$date_range[2]), "%d.%m.%Y")
      h4(paste0("Zeitraum (", tab, "): ", sd, " - ", ed))
    })
  }

  output$selected_date_range_text_veroeff  <- make_date_range_text("Veröffentlichungen")
  output$selected_date_range_text_views    <- make_date_range_text("Views")
  output$selected_date_range_text_likes    <- make_date_range_text("Likes")
  output$selected_date_range_text_comments <- make_date_range_text("Comments")
  output$selected_date_range_text_posts    <- make_date_range_text("Reposts")

  # Agenten-Daten + CSV
  agenten_data <- reactiveVal(agenten_data_df)

  # Globaler Speicherbutton
  observeEvent(input$global_save_btn, {
    req(agentenmodus())
    req(filtered_data())

    df_in_range <- filtered_data()
    if(nrow(df_in_range)==0) {
      showNotification("Keine Kanäle im Zeitraum.", type="warning")
      return()
    }
    df_range_agg <- get_range_aggregation(df_in_range)
    df_joined <- df_all_agg %>% inner_join(df_range_agg, by="channel")
    if(nrow(df_joined)==0) {
      showNotification("Keine Einträge im Zeitraum gefunden.", type="warning")
      return()
    }

    all_channels <- df_joined$channel
    data_now     <- agenten_data()

    for(cch in all_channels) {
      # Keys
      clean_chan  <- gsub("[^a-zA-Z0-9_]+","_", cch)
      manip_id    <- paste0("manip_",    clean_chan)
      strat_id    <- paste0("strat_",    clean_chan)
      notes_id    <- paste0("notes_",    clean_chan)
      official_id <- paste0("official_", clean_chan)
      suspicion_id<- paste0("suspicion_",clean_chan)
      delete_id   <- paste0("delete_",   clean_chan)
      nat_id      <- paste0("natural_",  clean_chan)

      # Input-Werte
      manip_val <- input[[manip_id]]
      strat_val <- input[[strat_id]]
      notes_val <- input[[notes_id]]
      off_val   <- isTRUE(input[[official_id]])
      susp_val  <- isTRUE(input[[suspicion_id]])
      del_val   <- isTRUE(input[[delete_id]])
      nat_val   <- isTRUE(input[[nat_id]])

      if(is.null(manip_val)) manip_val <- character(0)
      if(is.null(strat_val)) strat_val <- character(0)
      if(is.null(notes_val)) notes_val <- ""

      manip_str <- paste(manip_val, collapse=", ")
      strat_str <- paste(strat_val, collapse=", ")

      # Falls wir Uploader kennen => aus df_all_agg
      up_in_agg <- df_all_agg %>% filter(channel==cch) %>% select(first_uploader) %>% head(1)
      uploader_val <- if(nrow(up_in_agg)>0) {
        ifelse(is.na(up_in_agg$first_uploader[1]), "", up_in_agg$first_uploader[1])
      } else ""

      # exist row?
      existing_row <- data_now[data_now$channel==cch,]
      if(nrow(existing_row)==0){
        new_row <- data.frame(
          channel             = cch,
          uploader            = uploader_val,
          manipulationsmuster = manip_str,
          specific_strategies = strat_str,
          notes               = notes_val,
          delete_order        = del_val,
          official_political  = off_val,
          suspicion_case      = susp_val,
          natural_person      = nat_val,
          stringsAsFactors    = FALSE
        )
        data_now <- bind_rows(data_now, new_row)
      } else {
        # Overwrite row
        data_now <- data_now %>%
          mutate(
            uploader            = if_else(channel==cch, uploader_val, uploader),
            manipulationsmuster = if_else(channel==cch, manip_str, manipulationsmuster),
            specific_strategies = if_else(channel==cch, strat_str, specific_strategies),
            notes               = if_else(channel==cch, notes_val, notes),
            delete_order        = if_else(channel==cch, del_val, delete_order),
            official_political  = if_else(channel==cch, off_val, official_political),
            suspicion_case      = if_else(channel==cch, susp_val, suspicion_case),
            natural_person      = if_else(channel==cch, nat_val, natural_person)
          )
      }
    }

    agenten_data(data_now)
    write_csv(data_now, csv_file_path)
    showNotification("Alle Änderungen erfolgreich gespeichert!", type="message")
  })

  # Lokaler "Speichern (nur diese Karte)" pro Karte
  observe({
    if(!agentenmodus()) return()

    # Alle Channels
    all_channels <- df_all_agg$channel
    lapply(all_channels, function(cch){
      clean_chan  <- gsub("[^a-zA-Z0-9_]+","_", cch)
      local_save_id <- paste0("local_save_", clean_chan)

      manip_id    <- paste0("manip_",    clean_chan)
      strat_id    <- paste0("strat_",    clean_chan)
      notes_id    <- paste0("notes_",    clean_chan)
      official_id <- paste0("official_", clean_chan)
      suspicion_id<- paste0("suspicion_",clean_chan)
      delete_id   <- paste0("delete_",   clean_chan)
      nat_id      <- paste0("natural_",  clean_chan)

      if(!is.null(input[[local_save_id]])){
        observeEvent(input[[local_save_id]], {
          manip_val <- input[[manip_id]]
          strat_val <- input[[strat_id]]
          notes_val <- input[[notes_id]]
          off_val   <- isTRUE(input[[official_id]])
          susp_val  <- isTRUE(input[[suspicion_id]])
          del_val   <- isTRUE(input[[delete_id]])
          nat_val   <- isTRUE(input[[nat_id]])

          if(is.null(manip_val)) manip_val<-character(0)
          if(is.null(strat_val)) strat_val<-character(0)
          if(is.null(notes_val)) notes_val<-""

          manip_str <- paste(manip_val, collapse=", ")
          strat_str <- paste(strat_val, collapse=", ")

          # Uploader
          up_in_agg <- df_all_agg %>% filter(channel==cch) %>% select(first_uploader) %>% head(1)
          up_val <- if(nrow(up_in_agg)>0){
            ifelse(is.na(up_in_agg$first_uploader[1]), "", up_in_agg$first_uploader[1])
          } else ""

          current_data <- agenten_data()
          exrow <- current_data[current_data$channel==cch,]
          if(nrow(exrow)==0){
            new_row <- data.frame(
              channel             = cch,
              uploader            = up_val,
              manipulationsmuster = manip_str,
              specific_strategies = strat_str,
              notes               = notes_val,
              delete_order        = del_val,
              official_political  = off_val,
              suspicion_case      = susp_val,
              natural_person      = nat_val,
              stringsAsFactors    = FALSE
            )
            current_data <- bind_rows(current_data, new_row)
          } else {
            current_data <- current_data %>%
              mutate(
                uploader            = if_else(channel==cch, up_val, uploader),
                manipulationsmuster = if_else(channel==cch, manip_str, manipulationsmuster),
                specific_strategies = if_else(channel==cch, strat_str, specific_strategies),
                notes               = if_else(channel==cch, notes_val, notes),
                delete_order        = if_else(channel==cch, del_val, delete_order),
                official_political  = if_else(channel==cch, off_val, official_political),
                suspicion_case      = if_else(channel==cch, susp_val, suspicion_case),
                natural_person      = if_else(channel==cch, nat_val, natural_person)
              )
          }

          agenten_data(current_data)
          write_csv(current_data, csv_file_path)
          showNotification(paste0("Lokale Änderungen für Kanal '", cch, "' gespeichert."), type="message")
        })
      }
    })
  })

  # Render-Karten
  render_channel_cards <- function(metric_name){
    df_sum <- merge_and_sort(metric_name)
    if(nrow(df_sum)==0){
      return(tagList(h5("Keine Einträge im gewählten Zeitraum gefunden.")))
    }

    # Aktuelle Seite
    current_page <- if(metric_name=="veroeffentlichungen") veroeff_page() else
                    if(metric_name=="views") views_page() else
                    if(metric_name=="likes") likes_page() else
                    if(metric_name=="comments") comments_page() else
                    if(metric_name=="reposts") reposts_page()

    total_pages <- ceiling(nrow(df_sum)/page_size)
    if(current_page>total_pages){
      current_page<-total_pages
      if(current_page<1) current_page<-1
      if(metric_name=="veroeffentlichungen") veroeff_page(current_page)
      if(metric_name=="views") views_page(current_page)
      if(metric_name=="likes") likes_page(current_page)
      if(metric_name=="comments") comments_page(current_page)
      if(metric_name=="reposts") reposts_page(current_page)
    }

    start_idx <- (current_page-1)*page_size+1
    end_idx   <- min(current_page*page_size, nrow(df_sum))
    df_page   <- df_sum[start_idx:end_idx, ]

    # Neue Eingabewerte für "specific_strategies"
    # => Mögliche Techniken
    strategy_choices <- c(
          "Irreführende Selbstdarstellung als deutscher Kanal-Betreiber",
          "hohes Maß an Photo-Postings",
          "Untergrabung von Rechtsgrundlagen",
          "Fokussierung auf Informationsaggression",
          "Einsatz von generativer KI",
          "Starkes Follow/Follower-Ungleichgewicht",
          "Gezieltes Microtargeting",
          "Koordinierte Kommentar-Strategie",
          "soziologische Einflussnamhe",
          "Virales Sound/Nischen-Hashtag-Hijacking",
          "Mehrstufige Influencer-Kooperationen",
          "Manuelle Troll-Aktivitäten",
          "Emotionalisierte Kurzvideos"
    )

    card_list <- lapply(seq_len(nrow(df_page)), function(i){
      rowdata <- df_page[i,]
      rank_number <- start_idx + i -1
      channel_name<- rowdata$channel

      # Zeit
      date_first_str <- if(!is.na(rowdata$first_video_date)) {
        format(rowdata$first_video_date, "%d.%m.%Y %H:%M")
      } else "Unbekannt"
      date_last_str  <- if(!is.na(rowdata$last_video_date)) {
        format(rowdata$last_video_date, "%d.%m.%Y %H:%M")
      } else "Unbekannt"

      link_uploader <- rowdata$first_uploader
      link_url <- if(!is.na(link_uploader) && nchar(link_uploader)>0){
        paste0("https://www.tiktok.com/@", link_uploader)
      } else "#"

      channel_id_text <- if(!is.na(rowdata$channel_id)) rowdata$channel_id else ""

      total_count   <- rowdata$total_count
      total_views   <- rowdata$total_views
      total_likes   <- rowdata$total_likes
      total_comments<- rowdata$total_comments
      total_reposts <- rowdata$total_reposts
      range_count   <- rowdata$range_count

      # Lade agenten-Daten
      current_data <- agenten_data()
      agent_row <- current_data[current_data$channel==channel_name,]
      existing_manip      <- ""
      existing_strat      <- ""
      existing_notes      <- ""
      existing_official   <- FALSE
      existing_suspicion  <- FALSE
      existing_delete     <- FALSE
      existing_natural    <- FALSE
      uploader_in_csv     <- ""
      if(nrow(agent_row)>0){
        if(!is.na(agent_row$manipulationsmuster)) existing_manip  <- agent_row$manipulationsmuster
        if(!is.na(agent_row$specific_strategies)) existing_strat  <- agent_row$specific_strategies
        if(!is.na(agent_row$notes))               existing_notes  <- agent_row$notes
        if(!is.na(agent_row$official_political))  existing_official  <- agent_row$official_political
        if(!is.na(agent_row$suspicion_case))      existing_suspicion <- agent_row$suspicion_case
        if(!is.na(agent_row$delete_order))        existing_delete    <- agent_row$delete_order
        if(!is.na(agent_row$natural_person))      existing_natural   <- agent_row$natural_person
        if(!is.na(agent_row$uploader))            uploader_in_csv    <- agent_row$uploader
      }

      # Kopier-Text
      copy_lines <- c(
        paste0("Kanal: ", channel_name),
        paste0("Uploader: ", ifelse(is.na(link_uploader),"",link_uploader)),
        paste0("Erster Post am: ", date_first_str),
        paste0("Letzter Post am: ", date_last_str),
        paste0("Veröffentlichungen insgesamt: ", total_count),
        paste0("Veröffentlichungen im Zeitraum: ", range_count),
        paste0("Views Total: ", total_views),
        paste0("Likes Total: ", total_likes),
        paste0("Comments Total: ", total_comments),
        paste0("Reposts Total: ", total_reposts),
        paste0("Link: ", link_url),
        paste0("ID: ", channel_id_text)
      )
      if(nchar(existing_manip)>0)  copy_lines<-c(copy_lines, paste0("Manipulationsmuster: ", existing_manip))
      if(nchar(existing_strat)>0) copy_lines<-c(copy_lines, paste0("Spez. Strategien: ", existing_strat))
      if(nchar(existing_notes)>0) copy_lines<-c(copy_lines, paste0("Notizen: ", existing_notes))
      if(existing_official)       copy_lines<-c(copy_lines, "Offizieller politischer Kanal: JA")
      if(existing_suspicion)      copy_lines<-c(copy_lines, "Verdachtsfall: JA")
      if(existing_delete)         copy_lines<-c(copy_lines, "Anordnung zur Löschung: JA")
      if(existing_natural)        copy_lines<-c(copy_lines, "Natürliche Person: JA")

      text_to_copy <- paste(copy_lines, collapse="\n")
      text_to_copy_escaped <- gsub("'", "\\\\'", text_to_copy)
      text_to_copy_escaped <- gsub("\n","\\\\n", text_to_copy_escaped)

      # Button => dieselbe Farbe wie "Steckbrief kopieren" => btn-primary
      copy_btn <- tags$button(
        class="btn btn-sm btn-primary",
        style="margin-top:5px;",
        onclick = paste0("navigator.clipboard.writeText('", text_to_copy_escaped,"')"),
        "Steckbrief kopieren"
      )

      # Farbliche Kennzeichnung
      card_style <- "border:1px solid #ccc; border-radius:5px; padding:10px; margin-bottom:15px; background-color:#f9f9f9;"
      if(existing_delete){
        card_style <- "border:1px solid #880000; border-radius:5px; padding:10px; margin-bottom:15px; background-color:#ff9999;"
      } else if(existing_suspicion){
        card_style <- "border:1px solid #f0c000; border-radius:5px; padding:10px; margin-bottom:15px; background-color:#fff3cd;"
      }

      # Agenteninfo
      agent_box <- NULL
      if(nchar(existing_manip)>0 || nchar(existing_strat)>0 || nchar(existing_notes)>0
         || existing_official || existing_suspicion || existing_delete || existing_natural){
        agent_box <- div(
          style="margin-top:8px; padding:5px; border:1px dashed #888; background:#fcfcfc;",
          tags$strong("Agenten-Informationen:"),
          if(nchar(existing_manip)>0){
            div(style="margin-left:10px; margin-top:5px;",
                tags$b("Muster: "), existing_manip)
          },
          if(nchar(existing_strat)>0){
            div(style="margin-left:10px; margin-top:5px;",
                tags$b("Spez. Strategien: "), existing_strat)
          },
          if(nchar(existing_notes)>0){
            div(style="margin-left:10px; margin-top:5px;",
                tags$b("Notizen: "), existing_notes)
          },
          if(existing_official){
            div(style="margin-left:10px; color:#2255ee; margin-top:5px;",
                tags$b("Offizieller politischer Kanal: JA"))
          },
          if(existing_suspicion){
            div(style="margin-left:10px; color:#ff9000; margin-top:5px; font-weight:bold;",
                "Verdachtsfall: JA")
          },
          if(existing_delete){
            div(style="margin-left:10px; color:#880000; margin-top:5px; font-weight:bold;",
                "Anordnung zur Löschung: JA")
          },
          if(existing_natural){
            div(style="margin-left:10px; color:#008888; margin-top:5px; font-weight:bold;",
                "Natürliche Person: JA")
          }
        )
      }

      # Steckbrief-Inhalt
      content <- tagList(
        div(style="text-align:right; font-weight:bold; margin-bottom:8px;", paste0("#", rank_number)),
        div(style="margin-bottom:5px; font-weight:bold; font-size:16px;", paste0("Kanal: ", channel_name)),
        if (!is.na(link_uploader) && nchar(link_uploader)>0){
          div(style="margin-bottom:5px; font-size:14px; color:#555;",
              tags$b("Uploader: "), link_uploader,
              tags$br(),
              tags$a(href=link_url, target="_blank", link_url)
          )
        },
        div(style="margin-bottom:5px;", tags$b("Erster Post am:"), tags$br(), date_first_str),
        div(style="margin-bottom:5px;", tags$b("Letzter Post am:"), tags$br(), date_last_str),
        div(style="margin-bottom:5px;", tags$b("Veröffentlichungen insgesamt:"), tags$br(), total_count),
        div(style="margin-bottom:5px;", tags$b("Veröffentlichungen im Zeitraum:"), tags$br(), range_count),
        div(style="margin-bottom:5px;", tags$b("Views Total:"), tags$br(), total_views),
        div(style="margin-bottom:5px;", tags$b("Likes Total:"), tags$br(), total_likes),
        div(style="margin-bottom:5px;", tags$b("Comments Total:"), tags$br(), total_comments),
        div(style="margin-bottom:5px;", tags$b("Reposts Total:"), tags$br(), total_reposts),
        if(is.na(link_uploader) || nchar(link_uploader)==0){
          div(style="margin-bottom:5px;", tags$b("Link:"), tags$br(), "#")
        },
        div(style="margin-bottom:5px;", tags$b("Channel ID:"), tags$br(),
            div(style="word-wrap:break-word; white-space:pre-wrap; font-size:10px; color:#666;",
                channel_id_text)
        ),
        copy_btn,
        agent_box
      )

      if(agentenmodus()){
        # IDs
        clean_chan  <- gsub("[^a-zA-Z0-9_]+","_", channel_name)
        manip_id    <- paste0("manip_",    clean_chan)
        strat_id    <- paste0("strat_",    clean_chan)
        notes_id    <- paste0("notes_",    clean_chan)
        official_id <- paste0("official_", clean_chan)
        suspicion_id<- paste0("suspicion_",clean_chan)
        delete_id   <- paste0("delete_",   clean_chan)
        nat_id      <- paste0("natural_",  clean_chan)
        local_save_id <- paste0("local_save_", clean_chan)

        manip_val <- if(nchar(existing_manip)==0) character(0) else strsplit(existing_manip,",\\s*")[[1]]
        strat_val <- if(nchar(existing_strat)==0) character(0) else strsplit(existing_strat,",\\s*")[[1]]

        # UI für Agentenmodus
        extra_ui <- tagList(
          tags$hr(),
          materialSwitch(
            inputId=official_id,
            label="Offizieller politischer Kanal?",
            value=existing_official,
            status="primary"
          ),
          materialSwitch(
            inputId=nat_id,
            label="Natürliche Person ?",
            value=existing_natural,
            status="info"
          ),
          materialSwitch(
            inputId=suspicion_id,
            label="Verdachtsfall ",
            value=existing_suspicion,
            status="warning"
          ),
          materialSwitch(
            inputId=delete_id,
            label="Anordnung zur Löschung",
            value=existing_delete,
            status="danger"
          ),
          tags$hr(),
          pickerInput(
            inputId=manip_id,
            label="Erkannte Manipulationsmuster:",
            choices=c(
              "Instrumentalisierung von Werten, Mythen und Traditionen einer Gesellschaft", 
              "Verkürzung oder Auslassung von Fakten und Sachverhalten und deren Kontexten", 
              "Mängel rationaler Analyse, defiziente Logik, schwache Kohärenz,", 
              "Vermeidung/Ausschaltung von Multiperspektivität, Pluralismus, Widerspruch, Zweifel",
              "Anwendung des Freund-Feind-Schemas (Tabuisierung anderer Meinungen)",
              "Anspruch auf allgemeine Geltung der Sichtweise"
            ),
            selected=if(length(manip_val)==0) NULL else manip_val,
            multiple=TRUE,
            options=pickerOptions(actionsBox=TRUE, selectedTextFormat="count>2", liveSearch=TRUE)
          ),
          pickerInput(
            inputId=strat_id,
            label="Spezifische Strategien:",
            choices=strategy_choices,
            selected=if(length(strat_val)==0)NULL else strat_val,
            multiple=TRUE,
            options=pickerOptions(actionsBox=TRUE, selectedTextFormat="count>2", liveSearch=TRUE)
          ),
          textAreaInput(
            inputId=notes_id,
            label="Zusätzliche Hinweise:",
            value=existing_notes,
            rows=3
          ),
          # Lokaler Speichern
          actionButton(local_save_id, "Speichern", class="btn btn-primary btn-sm")
        )
        content <- tagList(content, extra_ui)

        # Switch-Exklusivität (falls gewünscht)
        # => So wie bisher Verdachtsfall und Löschung sich gegenseitig ausschließen
        observeEvent(input[[suspicion_id]], {
          if(isTRUE(input[[suspicion_id]])) {
            updateMaterialSwitch(session, delete_id, value=FALSE)
          }
        }, ignoreInit=TRUE)
        observeEvent(input[[delete_id]], {
          if(isTRUE(input[[delete_id]])) {
            updateMaterialSwitch(session, suspicion_id, value=FALSE)
          }
        }, ignoreInit=TRUE)
      }

      column(width=4, div(style=card_style, content))
    })

    chunk_to_rows(card_list, 3)
  }

  # Render
  output$cards_veroeffentlichungen <- renderUI({ render_channel_cards("veroeffentlichungen") })
  output$cards_views <- renderUI({ render_channel_cards("views") })
  output$cards_likes <- renderUI({ render_channel_cards("likes") })
  output$cards_comments <- renderUI({ render_channel_cards("comments") })
  output$cards_reposts <- renderUI({ render_channel_cards("reposts") })
}

cat("==== Starting shinyApp ====\n")
shinyApp(ui, server, options=list(host="0.0.0.0", port=5025, launch.browser=FALSE))
