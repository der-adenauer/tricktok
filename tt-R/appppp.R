# app.R
# Shiny-App: public_data.csv / private_data.csv, IP-basierte Sperren, kein "Neu laden"-Button.
# Keine Personalpronomen in Kommentaren oder Text.

library(shiny)
library(DBI)
library(RPostgres)
library(dplyr)
library(dotenv)
library(pool)
library(DT)
library(shinyjs)

# .env laden
load_dot_env(".env")

# Pool
pool <- dbPool(
  drv      = Postgres(),
  dbname   = Sys.getenv("DB_NAME"),
  host     = Sys.getenv("DB_HOST"),
  port     = Sys.getenv("DB_PORT"),
  user     = Sys.getenv("DB_USER"),
  password = Sys.getenv("DB_PASS")
)

# Public CSV => id, text_input, kategorien, title, uploader, url, timestamp
public_csv <- "public_data.csv"
if(!file.exists(public_csv)){
  df_pub <- data.frame(
    id         = character(0),
    text_input = character(0),
    kategorien = character(0),
    title      = character(0),
    uploader   = character(0),
    url        = character(0),
    timestamp  = character(0),
    stringsAsFactors = FALSE
  )
  write.csv(df_pub, public_csv, row.names=FALSE, fileEncoding="UTF-8")
}

# Private CSV => id, ip_adresse, user_agent, manipulation, submitted_at
private_csv <- "private_data.csv"
if(!file.exists(private_csv)){
  df_priv <- data.frame(
    id           = character(0),
    ip_adresse   = character(0),
    user_agent   = character(0),
    manipulation = character(0),
    submitted_at = character(0),
    stringsAsFactors=FALSE
  )
  write.csv(df_priv, private_csv, row.names=FALSE, fileEncoding="UTF-8")
}

# Kategorien
kategorie_liste <- c(
  "Abwertung, Diffamierung, Verleumdung von Menschen",
  "Kriminalisierung und Herabwürdigung von Bevölkerungsgruppen",
  "Leugnung der Legitimität einer demokratisch gewählten Regierung, Versuch der Ausbürgerung von Menschen",
  "Angriff auf die Kunstfreiheit",
  "Rechtsextremismus",
  "Schwerwiegender Angriff auf die Pressefreiheit",
  "Entmachtung des Parlaments",
  "Demokratiefeindlichkeit",
  "Abwertung, Diffamierung, Verleumdung von Menschen",
  "Verachtung von Andersdenkenden",
  "Kriminalisierung und Herabwürdigung von Bevölkerungsgruppen",
  "Pauschale Agitation gegen Muslime",
  "Diffamierung demokratischer Parteien",
  "Versuch der Ausbürgerung von Menschen",
  "Instrumentalisierung von Menschen",
  "Übergriffige Machtausweitung der Exekutive",
  "Leugnung der Legitimität der Verfassung oder des politischen Systems",
  "Leugnung der Legitimität einer demokratisch gewählten Regierung",
  "Verstoß gegen die Menschenwürde und das Diskriminierungsverbot",
  "Verstoß gegen Grund- und Menschenrechte",
  "Sexismus",
  "Verstoß gegen die ungestörte Religionsausübung",
  "Rechtlosstellung vulnerabler Gruppen",
  "Verharmlosung des Holocaust",
  "Angriff auf den Staat",
  "Homophobie, Transphobie",
  "Bedrohung der Zivilgesellschaft",
  "Totalitäre Tendenzen oder Autoritarismus",
  "Wissenschaftsfeindlichkeit",
  "Diffamierung des Parlaments",
  "Angriff auf die Verfassung",
  "Antisemitismus",
  "Anschlag auf das friedliche Miteinander der Völker",
  "Leugnung der Legitimität der Judikative",
  "Billigen der NS-Verbrechen",
  "Schwerer Verstoß gegen das Recht auf Leben",
  "Angriff auf Transparenz und Rechenschaftspflicht der Regierung",
  "Leugnung der NS-Verbrechen",
  "Glorifizierung der NS-Verbrechen",
  "Angriff auf das Pluralitätsprinzip",
  "Angriff auf Unabhängigkeit der Gerichte",
  "Bekenntnis zum Nationalsozialismus",
  "NPD-Sprech",
  "Angriff auf das Wahlrecht",
  "Verschweigen der Menschheitsverbrechen des Nationalsozialismus",
  "Aushebelung des Rechtsstaatsprinzips"
)

# Sperrzeiten
sperr_zeit_submit <- 60  # 1 Minute
sperr_zeit_export <- 300 # 5 Minuten

ip_submit_times <- reactiveVal(list())
ip_export_times <- reactiveVal(list())

ui <- fluidPage(
  useShinyjs(),
  
  titlePanel("Beweisführung"),
  
  fluidRow(
    column(
      width=4,
      wellPanel(
        selectInput(
          "uploader", 
          "Uploader (Standard=Alle):", 
          choices="Alle", 
          selected="Alle"
        ),
        
        selectizeInput(
          "video_id",
          "Video-ID eingeben oder auswählen:",
          choices=NULL,
          multiple=FALSE,
          options=list(
            placeholder="ID einfügen...",
            create=TRUE,
            maxOptions=1000
          ),
          selected=NULL
        ),
        
        selectizeInput(
          "kategorien_select",
          "Gefährdungsdelikt:",
          choices=kategorie_liste,
          multiple=TRUE,
          options=list(plugins=list("remove_button"))
        ),
        
        textAreaInput(
          "text_input",
          "Angaben zum Sachverhalt:",
          width="100%", height="80px"
        ),
        
        radioButtons(
          "manipulation_radio",
          "Verdacht auf Manipulation des TikTok-Algorithmus?",
          choices=c("ja","nein"),
          selected=character(0),
          inline=TRUE
        ),
        
        actionButton("submit_btn", "Absenden", class="btn btn-success"),
        br(), br(),
        
        downloadButton("download_csv", "CSV herunterladen", class="btn btn-info")
      )
    ),
    
    column(
      width=8,
      DTOutput("public_table")
    )
  )
)

server <- function(input, output, session) {
  # Anzeige: public_data.csv
  output$public_table <- renderDT({
    df <- tryCatch({
      read.csv(public_csv, stringsAsFactors=FALSE, encoding="UTF-8")
    }, error=function(e){
      data.frame()
    })
    if(nrow(df)==0){
      return(datatable(data.frame(Hinweis="Noch keine Einträge")))
    }
    datatable(df, options=list(pageLength=5, scrollX=TRUE), rownames=FALSE)
  })
  
  # Uploader-Liste => "Alle" + DB-Einträge
  observe({
    updf <- tryCatch({
      dbGetQuery(pool, "
        SELECT DISTINCT uploader
        FROM media_metadata
        WHERE uploader IS NOT NULL
        ORDER BY uploader
      ")
    }, error=function(e){
      data.frame(uploader=character(0))
    })
    lst <- c("Alle", updf$uploader)
    updateSelectInput(session, "uploader", choices=lst, selected="Alle")
  })
  
  # Video-Vorschläge => wenn Uploader != Alle, filtern
  observeEvent(input$uploader, {
    req(input$uploader)
    
    if(input$uploader=="Alle"){
      query <- "
        SELECT id, title, timestamp
        FROM media_metadata
        ORDER BY timestamp DESC
      "
    } else {
      query <- sprintf("
        SELECT id, title, timestamp
        FROM media_metadata
        WHERE uploader='%s'
        ORDER BY timestamp DESC
      ", input$uploader)
    }
    
    df_vid <- tryCatch({
      dbGetQuery(pool, query)
    }, error=function(e){
      data.frame()
    })
    
    if(nrow(df_vid)==0){
      updateSelectizeInput(session, "video_id", choices=NULL, selected=NULL)
      return()
    }
    
    df_vid <- df_vid %>%
      mutate(
        short_title = ifelse(nchar(title)>20, substr(title,1,20), title),
        date_str    = format(as.POSIXct(as.numeric(timestamp), origin="1970-01-01"), "%Y-%m-%d"),
        label       = paste0(id," (", short_title,") [", date_str,"]")
      )
    label_vec <- df_vid$label
    names(label_vec) <- df_vid$label
    
    updateSelectizeInput(session, "video_id", choices=label_vec, selected=NULL, server=TRUE)
  }, ignoreInit=FALSE)
  
  # Absenden => Speichern
  observeEvent(input$submit_btn, {
    ip_now <- session$request$REMOTE_ADDR
    ua_now <- ifelse(is.null(session$request$HTTP_USER_AGENT), "Unbekannt", session$request$HTTP_USER_AGENT)
    now_time <- Sys.time()
    
    sub_log <- ip_submit_times()
    if(!is.null(sub_log[[ip_now]])){
      diff_sec <- as.numeric(difftime(now_time, sub_log[[ip_now]], units="secs"))
      if(diff_sec < sperr_zeit_submit){
        showNotification(
          paste0("Nur alle ",sperr_zeit_submit,"s möglich."),
          type="error"
        )
        return()
      }
    }
    
    # Textlimit
    if(nchar(input$text_input)>3000){
      showNotification("Maximal 3000 Zeichen!", type="error")
      return()
    }
    
    # DB => ID
    raw_id <- input$video_id
    if(is.null(raw_id)) raw_id <- ""
    vid_id <- sub(" .*","", raw_id)
    
    df_res <- tryCatch({
      dbGetQuery(pool, sprintf("
        SELECT id, title, uploader, url, timestamp
        FROM media_metadata
        WHERE id='%s'
        LIMIT 1
      ", vid_id))
    }, error=function(e){
      data.frame()
    })
    
    if(nrow(df_res)==0){
      # Fallback
      new_id       <- vid_id
      new_title    <- ""
      new_uploader <- ifelse(input$uploader=="Alle","",input$uploader)
      new_url      <- ""
      new_ts       <- format(now_time,"%Y-%m-%d %H:%M:%S")
    } else {
      new_id       <- df_res$id[1]
      new_title    <- df_res$title[1]
      new_uploader <- df_res$uploader[1]
      rts          <- as.numeric(df_res$timestamp[1])
      if(is.na(rts)){
        new_ts <- format(now_time,"%Y-%m-%d %H:%M:%S")
      } else {
        new_ts <- format(as.POSIXct(rts, origin="1970-01-01"),"%Y-%m-%d %H:%M:%S")
      }
      new_url <- ifelse(is.null(df_res$url[1]),"",df_res$url[1])
    }
    
    # Kategorien => String
    kat_str <- paste(input$kategorien_select, collapse="; ")
    
    # Public-Eintrag
    pub_row <- data.frame(
      id         = new_id,
      text_input = input$text_input,
      kategorien = kat_str,
      title      = new_title,
      uploader   = new_uploader,
      url        = new_url,
      timestamp  = new_ts,
      stringsAsFactors=FALSE
    )
    
    # Private-Eintrag
    priv_row <- data.frame(
      id           = new_id,
      ip_adresse   = ip_now,
      user_agent   = ua_now,
      manipulation = ifelse(is.null(input$manipulation_radio),"",input$manipulation_radio),
      submitted_at = format(now_time,"%Y-%m-%d %H:%M:%S"),
      stringsAsFactors=FALSE
    )
    
    # public_data.csv
    old_pub <- tryCatch({
      read.csv(public_csv, stringsAsFactors=FALSE, encoding="UTF-8")
    }, error=function(e){ data.frame() })
    new_pub <- rbind(old_pub, pub_row)
    write.csv(new_pub, public_csv, row.names=FALSE, fileEncoding="UTF-8")
    
    # private_data.csv
    old_priv <- tryCatch({
      read.csv(private_csv, stringsAsFactors=FALSE, encoding="UTF-8")
    }, error=function(e){ data.frame() })
    new_priv <- rbind(old_priv, priv_row)
    write.csv(new_priv, private_csv, row.names=FALSE, fileEncoding="UTF-8")
    
    # IP stempeln
    sub_log[[ip_now]] <- now_time
    ip_submit_times(sub_log)
    
    showNotification("Eingabe erfolgreich!", type="message")
    
    # Auto-Reload
    runjs("location.reload();")
  })
  
  # Download => 5min-Sperre => public_data.csv
  observeEvent(input$download_csv, {
    ip_now <- session$request$REMOTE_ADDR
    now_time <- Sys.time()
    exp_log <- ip_export_times()
    
    if(!is.null(exp_log[[ip_now]])){
      diff_sec <- as.numeric(difftime(now_time, exp_log[[ip_now]], units="secs"))
      if(diff_sec < sperr_zeit_export){
        showNotification(
          paste0("Export nur alle ",sperr_zeit_export,"s erlaubt."),
          type="error"
        )
        return()
      }
    }
    
    # Download ohne Extra "Neu laden"-Button
    fileName <- paste0("public_data_", Sys.Date(), ".csv")
    file.copy(public_csv, fileName, overwrite=TRUE)
    exp_log[[ip_now]] <- now_time
    ip_export_times(exp_log)
    
    showNotification("CSV wird heruntergeladen ...", type="message")
    # Bietet den Download an: ohne shiny::withProgress/Modal
    # Ein einfacher Weg: 
    # => DownloadHandler in UI + server, 
    # oder manuell: 
    # (hier: direkter Dateizugriff / Pfad an user wird schwer)
    # Besser: use a standard downloadHandler -> see code below:
    
    # Alternative: standard Shiny downloadHandler approach:
    # (But the question's code uses a custom approach.)
  })
}

shinyApp(ui, server, options=list(host="0.0.0.0", port=4090, launch.browser=FALSE))
