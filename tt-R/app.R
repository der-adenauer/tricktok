#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# ==================================================
# Shiny-App:
#   - 18 Sektionen (neue Reihenfolge)
#   - Navigation über < zurück / weiter >
#   - Navbar (Top-Bar) sticky oben
#   - Hamburger-Menü von links
#   - Reload-Button und Logo rechts
#   - Keine globalen Scrollbalken (Overflow: hidden)
#   - Metadaten / Anheuern / Impressum: Text im Blocksatz
#   - Wechselanimation: nächste Seite fällt von oben herab (SlideDown)
#   - In den meisten Sektionen 10% Abstand (links/rechts)
#   - Adenauer OS / Fahndungsliste / Contentschleuder: Vollbild (unterhalb Top-Bar)
#   - 30s Cooldown für alle CSV-Downloads
#   - Startseite mit drei Typewriter-Zeilen (inkl. Zeilenumbruch)
#   - Navbar zeigt LIVE-Log (Datenbankzugriffe etc.)
#   - Neue Reihenfolge:
#       0)  Start
#       1)  Einführung
#       2)  live
#       3)  Adenauer OS Tutorial
#       4)  Adenauer OS
#       5)  Fahndung
#       6)  Metadaten
#       7)  Propaganda-Bots
#       8)  Statistiktok
#       9)  Zeitreihen
#       10) Hashtag
#       11) Contentschleuder
#       12) Hitparade
#       13) Photo-Archiv
#       14) Video-Archiv
#       15) Beweisführung
#       16) Anheuern
#       17) Impressum
# ==================================================

options(shiny.fullstacktrace = TRUE)
options(shiny.error = traceback)
options(shiny.sanitize.errors = FALSE)
options(shiny.trace = TRUE)
options(shiny.reactlog = TRUE)

library(shiny)
library(DBI)
library(RPostgres)
library(dplyr)
library(lubridate)
library(markdown)
library(dotenv)

cat("==== START APP SCRIPT ====\n")

# -------------------------------------------------------
# Globale Variablen für 30s-Cooldown
# -------------------------------------------------------
LAST_DOWNLOAD_TIME <- as.numeric(Sys.time()) - 9999
COOLDOWN_SECONDS   <- 30

# -------------------------------------------------------
# Hilfsfunktionen: Datenbank-Abfragen
# -------------------------------------------------------
lade_links <- function(con) {
  query <- "SELECT id, url, inserted_at, processed FROM links ORDER BY id DESC"
  df <- dbGetQuery(con, query)
  cat("[lade_links] Zeilenanzahl:", nrow(df), "\n")
  df
}

lade_media_metadata <- function(con) {
  query <- "
    SELECT
      id, url, title, description, duration, view_count,
      like_count, repost_count, comment_count, uploader,
      uploader_id, channel, channel_id, channel_url, track,
      album, artists, timestamp, extractor
    FROM media_metadata
    ORDER BY id DESC
  "
  df <- dbGetQuery(con, query)
  cat("[lade_media_metadata] Zeilenanzahl:", nrow(df), "\n")
  if ("timestamp" %in% names(df)) {
    df$timestamp <- as.numeric(df$timestamp)
  }
  df
}

lade_media_time_series <- function(con) {
  query <- "
    SELECT
      series_id, url, view_count, like_count, repost_count,
      comment_count, recorded_at
    FROM media_time_series
    ORDER BY series_id DESC
  "
  df <- dbGetQuery(con, query)
  cat("[lade_media_time_series] Zeilenanzahl:", nrow(df), "\n")
  df
}

# -------------------------------------------------------
# Reihenfolge & Titel der 18 Sektionen
# -------------------------------------------------------
# 0)  Start
# 1)  Einführung
# 2)  live
# 3)  Adenauer OS Tutorial
# 4)  Adenauer OS
# 5)  Fahndung
# 6)  Metadaten
# 7)  Propaganda-Bots
# 8)  Statistiktok
# 9)  Zeitreihen
# 10) Hashtag
# 11) Contentschleuder
# 12) Hitparade
# 13) Photo-Archiv
# 14) Video-Archiv
# 15) Beweisführung
# 16) Anheuern
# 17) Impressum

# -------------------------------------------------------
# Benutzeroberfläche
# -------------------------------------------------------
ui <- fluidPage(
  style = "margin:0; padding:0;",

  tags$head(
    tags$meta(
      name    = "viewport",
      content = "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"
    ),

    # --------------------------------
    # JavaScript: Navigation + Menü-Steuerung
    # --------------------------------
    tags$script(HTML("
      var currentSectionIndex = 0;
      var sections = [];
      var sectionTitles = [
        'Start',
        'Einführung',
        'live',
        'Adenauer OS Tutorial',
        'Adenauer OS',
        'Fahndung',
        'Metadaten',
        'Propaganda-Bots',
        'Statistiktok',
        'Zeitreihen',
        'Hashtag',
        'Contentschleuder',
        'Hitparade',
        'Photo-Archiv',
        'Video-Archiv',
        'Beweisführung',
        'Anheuern',
        'Impressum'
      ];

      function openNav(){
        var sn = document.getElementById('mySidenav');
        if(sn) sn.style.width = '250px';
      }
      function closeNav(){
        var sn = document.getElementById('mySidenav');
        if(sn) sn.style.width = '0';
      }
      document.addEventListener('click', function(e){
        var sidenav = document.getElementById('mySidenav');
        var hamburgerBtn = document.getElementById('hamburgerBtn');
        if(sidenav && hamburgerBtn && !sidenav.contains(e.target) && !hamburgerBtn.contains(e.target)){
          closeNav();
        }
      });
      document.addEventListener('DOMContentLoaded', function(){
        sections = document.getElementsByClassName('sectionBlock');
        zeigeAktiveSektion(0);
      });

      function zeigeAktiveSektion(index){
        if(index < 0 || index >= sections.length){ return; }
        for(var i=0; i<sections.length; i++){
          sections[i].classList.remove('activeSection');
        }
        sections[index].classList.add('activeSection');
        var heading = document.getElementById('currentHeading');
        if(heading) heading.textContent = sectionTitles[index];
        currentSectionIndex = index;
      }

      function geheVor(){
        if(currentSectionIndex < sections.length - 1){
          zeigeAktiveSektion(currentSectionIndex + 1);
        }
      }
      function geheZurueck(){
        if(currentSectionIndex > 0){
          zeigeAktiveSektion(currentSectionIndex - 1);
        }
      }
    ")),

    # --------------------------------
    # CSS
    # --------------------------------
    tags$style(HTML("
      html, body {
        margin: 0;
        padding: 0;
        overflow: hidden; /* Keine globalen Scrollbalken */
        font-family: sans-serif;
        background-color: #fff;
      }
      .topBar {
        position: fixed;
        top: 0;
        left: 0;
        right: 0;
        z-index: 10002;
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 5px 10px;
        background-color: #fff;
        box-shadow: 0 2px 4px rgba(0,0,0,0.1);
      }
      .topBarLeft {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      .topBarCenter {
        flex: 1;
        text-align: center;
        font-size: 14px;
        color: #666;
        opacity: 0.7;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
      }
      .topBarRight {
        display: flex;
        align-items: center;
        gap: 10px;
      }
      #hamburgerBtn {
        border: none;
        background-color: transparent;
        font-size: 28px;
        cursor: pointer;
      }
      #currentHeading {
        font-size: 20px;
        font-weight: bold;
      }
      .reloadIcon {
        width: 40px;
        height: 40px;
        background-color: #ddd;
        border-radius: 50%;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        transition: transform 0.3s;
        font-size: 20px;
      }
      .reloadIcon:hover {
        transform: rotate(360deg);
      }
      #logoImage {
        width: 100px;
        height: auto;
      }

      .sidenav {
        height: 100%;
        width: 0;
        position: fixed;
        z-index: 10000;
        top: 0;
        left: 0;
        background-color: rgba(255,255,255,0.95);
        overflow-x: hidden;
        transition: 0.3s;
        padding-top: 60px;
      }
      .sidenav a {
        padding: 8px 8px 8px 16px;
        text-decoration: none;
        font-size: 18px;
        color: #000;
        display: block;
        font-weight: bold;
        transition: 0.3s;
      }
      .sidenav a:hover {
        background-color: #ddd;
      }
      .sidenav .closebtn {
        position: absolute;
        top: 0;
        left: 210px;
        font-size: 40px;
      }

      .navButtons {
        position: fixed;
        bottom: 10px;
        right: 10px;
        z-index: 10003;
        display: flex;
        gap: 10px;
      }
      .navButton {
        padding: 10px 15px;
        background-color: #444;
        color: #fff;
        border: none;
        cursor: pointer;
        font-size: 16px;
        border-radius: 4px;
      }
      .navButton:hover {
        background-color: #555;
      }

      .sectionBlock {
        position: absolute;
        top: 60px;
        left: 0;
        width: 100%;
        height: calc(100vh - 60px);
        visibility: hidden;
        opacity: 0;
        transform: translateY(-100%);
        transition: transform 0.6s ease, opacity 0.6s ease, visibility 0.6s;
        overflow: hidden;  /* Jede Sektion ohne globale Scrollbar */
      }
      .sectionBlock.activeSection {
        visibility: visible;
        opacity: 1;
        transform: translateY(0);
      }

      .sectionContent {
        padding-top: 30px;
        padding-bottom: 0;
        margin-left: 10%;
        margin-right: 10%;
        text-align: left;
        height: calc(100% - 30px);
      }
      @media (max-width: 768px){
        .sectionContent {
          margin-left: 3%;
          margin-right: 3%;
        }
      }

      /* Hintergründe */
      #section_start       { background-color: #ffffff; }
      #section_intro       { background-color: #ffffff; position: relative; }
      #section_adenaueros  { background-color: #cccccc; }
      #section_fahndung    { background-color: #cccccc; }
      #section_meta        { background-color: #ffffff; }
      #section_zeitreihen  { background-color: #ffffff; }
      #section_iframeExtra { background-color: #ffffff; }
      #section_hashtag     { background-color: #ffffff; }
      #section_medienholen { background-color: #cccccc; }
      #section_photoarchiv { background-color: #ffffff; }
      #section_videoarchiv { background-color: #ffffff; }
      #section_reiter2     { background-color: #ffffff; }
      #section_anheuern    { background-color: #ffffff; }
      #section_impressum   { background-color: #ffffff; }

      #section_adenaueros .sectionContent,
      #section_fahndung   .sectionContent,
      #section_medienholen .sectionContent {
        margin: 0;
        padding: 0;
        width: 100%;
        height: 100%;
      }
      #section_adenaueros .iframe-wrapper,
      #section_fahndung   .iframe-wrapper,
      #section_medienholen .iframe-wrapper {
        width: 100%;
        height: 100%;
      }

      #section_meta .sectionContent,
      #section_anheuern .sectionContent,
      #section_impressum .sectionContent {
        text-align: justify;
      }

      .exportButtons {
        text-align: center;
        margin: 20px 0;
      }
      .exportButtons button {
        margin: 0 10px;
      }

      .markdown-container {
        margin-top: 20px;
        max-width: 800px;
        margin-left: auto;
        margin-right: auto;
      }

      .iframe-wrapper {
        width: 100%;
        height: 100%;
      }
      .iframe-wrapper iframe {
        width: 100%;
        height: 100%;
        border: none;
        display: block;
      }

      .start-flex-container {
        display: flex;
        flex-wrap: wrap;
        align-items: center;
        justify-content: center;
      }
      .start-image {
        flex: 1 1 300px;
        min-width: 280px;
        max-width: 600px;
        margin-right: 20px;
      }
      .start-typer {
        flex: 1 1 300px;
        margin-top: 20px;
        background-color: #fff;
        color: #000;
      }
      @media (max-width: 768px) {
        .start-image {
          margin-right: 0;
          margin-bottom: 20px;
        }
      }

      /* Typewriter-Stil, alle Zeilen gleichzeitig, Laufzeit 2.5s */
      .typewriter-line {
        position: relative;
        display: inline-block;
        white-space: nowrap;
        overflow: hidden;
        font-family: monospace;
        font-size: 24px;
        margin-bottom: 20px;
      }
      .typewriter-cursor {
        border-right: 3px solid #000;
        position: absolute;
        right: -10px;
        animation: blinkCursor 600ms steps(30,end) infinite;
        height: 1.2em;
      }
      @keyframes blinkCursor {
        from { border-color: #000; }
        to   { border-color: transparent; }
      }

      /* Jedes Element bekommt seine Keyframes, 
         alle starten direkt ohne Verzögerung, 
         Laufzeit 2.5s */
      #line1Anim {
        animation: typingLine1 2.5s steps(16,end) 0s 1 normal both;
        width: 0;
      }
      @keyframes typingLine1 {
        from { width: 0; }
        to   { width: 16ch; }
      }

      #line2Anim {
        animation: typingLine2 2.5s steps(55,end) 0s 1 normal both;
        width: 0;
      }
      @keyframes typingLine2 {
        from { width: 0; }
        to   { width: 55ch; }
      }

      #line3Anim {
        animation: typingLine3 2.5s steps(36,end) 0s 1 normal both;
        width: 0;
      }
      @keyframes typingLine3 {
        from { width: 0; }
        to   { width: 36ch; }
      }

      @media (max-width: 768px){
        .typewriter-line {
          font-size: 16px;
        }
      }

      /* =========================================================
         CSS für Scrollytelling innerhalb der Einführung (Section #1)
         ========================================================= */
      .scrollWrapper {
        width: 100%;
        height: 100%;
        overflow-y: auto;   /* Lokales Scrollen */
        box-sizing: border-box;
        padding-bottom: 40px;
        -ms-overflow-style: none;  /* IE, Edge */
        scrollbar-width: none;     /* Firefox */
      }
      .scrollWrapper::-webkit-scrollbar {
        width: 0px; 
        background: transparent; /* Safari + Chrome */
      }
      .scroll-section {
        width: 100%;
        min-height: 60vh;
        padding: 40px;
        box-sizing: border-box;
      }
      .slogan-bar {
        background-color: #000000; 
        color: #FFFFFF;           
        font-size: 2.5em;     
        font-weight: bold;
        padding: 20px;
        margin: 40px 0;
        opacity: 0;
        transform: translateX(-100vw); 
        transition: all 1s ease;
        white-space: normal;  /* Zeilenumbruch ermöglichen */
        word-break: break-word;
        overflow: hidden;
        text-align: left;
        max-width: 100%;
      }
      .slogan-bar-right {
        transform: translateX(100vw);
        text-align: right;
      }
      .slogan-bar.show {
        opacity: 1;
        transform: translateX(0);
      }
      .story-img {
        display: block;
        max-width: 90%;
        margin: 40px auto;
      }
      .dummy-text {
        margin: 20px 0;
        line-height: 1.6;
        font-size: 1.2em; /* Größere Schrift im Fließtext */
      }
      @media only screen and (max-width: 600px) {
        .slogan-bar {
          font-size: 1.8em;
        }
        .dummy-text {
          font-size: 1.1em;
        }
      }

      /* =========================================================
         Wellen + Bilder in Section 'Einführung'
         ========================================================= */
      body, html {
        margin: 0;
        padding: 0;
      }

      /* Erste Welle */
      .wave {
        background-image: url('https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/background.svg');
        background-repeat: repeat-x;
        background-size: 500px auto;
        background-position: bottom;
        position: absolute;
        bottom: 0%;
        width: 100%;
        height: 200px;
        animation: wave 5s cubic-bezier(0.36, 0.45, 0.63, 0.53) infinite;
        z-index: 1;
      }

      /* Zweite Welle */
      .wave:nth-of-type(2) {
        opacity: 0.7;
        animation: swell 5s ease -1.25s infinite, wave 5s cubic-bezier(0.36, 0.45, 0.63, 0.53) -.125s infinite;
        z-index: 0;
      }

      @keyframes wave {
        0% {
          background-position-x: 0%;
        }
        100% {
          background-position-x: -500px;
        }
      }
      @keyframes swell {
        0%, 100% {
          background-position: right bottom 10px;
        }
        50% {
          background-position: right bottom 0;
        }
      }

      /* =========================================================
         Fünf Bilder als kleine Symbole, Bewegung synchron mit Welle
         ========================================================= */
.floating-images-container {
  position: relative;
  bottom: 650px;        /* Diese Zahl anpassen, um Höhe über dem Rand zu ändern */
  left: 0;
  width: 100%;
  height: 0;
  pointer-events: none;
  z-index: 0;           /* Hier den z-Index erhöhen oder verringern */
}


      .floating-image {
        position: absolute;
        display: none; /* Ausblenden bis zur Aktivierung */
        width: auto;
        height: auto;
        transform: scale(0.33); /* 3% Originalgröße */
        animation: floatUpDown 5s infinite ease-in-out; /* Gleiche Dauer wie wave */
      }

      /* Einfaches Auf-und-Ab (in Y-Richtung) für synchronen Effekt */
      @keyframes floatUpDown {
        0%, 100% {
          transform: translateY(0) scale(0.03);
        }
        50% {
          transform: translateY(-30px) scale(0.03);
        }
      }

      /* Horizontal-Animation: langsames Einblenden und von rechts -> links */
      .moveFromRight {
        animation: moveHorizontally 10s linear forwards;
        /* 5s = Dauer eines Wellenloops */
      }
      @keyframes moveHorizontally {
        0% {
          right: -100px; /* Start knapp rechts außerhalb */
          opacity: 0.0;
        }
        5% {
          opacity: 1.0;
        }
        100% {
          right: 100%; /* nach links raus */
          opacity: 1.0;
        }
      }
    ")),

    # --------------------------------
    # JavaScript für die Scrollytelling-Effekte & Bild-Trigger
    # --------------------------------
    tags$script(HTML("
      function checkSloganBars(){
        var sloganBars = document.querySelectorAll('.slogan-bar, .slogan-bar-right');
        for (var i = 0; i < sloganBars.length; i++) {
          var rect = sloganBars[i].getBoundingClientRect();
          var windowHeight = window.innerHeight || document.documentElement.clientHeight;
          if (rect.top <= windowHeight - 100 && rect.bottom >= 0) {
            sloganBars[i].classList.add('show');
          }
        }
      }

      document.addEventListener('DOMContentLoaded', function(){
        var scrollWrapper = document.getElementById('introScrollWrapper');
        if(scrollWrapper){
          scrollWrapper.addEventListener('scroll', checkSloganBars);
          setTimeout(function(){
            var bars = scrollWrapper.querySelectorAll('.slogan-bar, .slogan-bar-right');
            if(bars.length >= 2){
              bars[0].classList.add('show');
              bars[1].classList.add('show');
            }
          }, 200);
        }

        /* 
          Zähler für Wellenloops: alle 3 Durchläufe => nächstes Bild 
          Bilder in Array hinterlegen 
        */
        var wave = document.querySelector('.wave'); 
        var waveCount = 0;
        var imageIndex = 0;
        var floatingImages = document.querySelectorAll('.floating-image');

        if(wave){
          wave.addEventListener('animationiteration', function(){
            waveCount++;
            /* Alle 3 Durchläufe => ein Bild losfahren lassen */
            if(waveCount % 3 === 0){
              if(imageIndex < floatingImages.length){
                var img = floatingImages[imageIndex];
                img.style.display = 'block';
                /* separate Klasse für horizontale Bewegung anhängen */
                img.classList.add('moveFromRight');
                imageIndex++;
              }
            }
          });
        }
      });
    "))
  ),

  # --------------------------------------------------
  # Obere Leiste (Top-Bar) mit Live-Log
  # --------------------------------------------------
  div(
    class = "topBar",
    div(
      class = "topBarLeft",
      tags$button(
        id = "hamburgerBtn",
        HTML("&#9776;"),
        onclick = "openNav()"
      ),
      div(id = "currentHeading", "Start")
    ),
    div(
      id    = "loadingLog",
      class = "topBarCenter",
      textOutput("loadingStatus", inline = TRUE)
    ),
    div(
      class = "topBarRight",
      div(
        class = "reloadIcon",
        HTML("&#x21bb;"),
        onclick = "location.reload();"
      ),
      tags$img(
        id = "logoImage",
        src = "https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg"
      )
    )
  ),

  # --------------------------------------------------
  # Navigation unten rechts
  # --------------------------------------------------
  div(
    class = "navButtons",
    tags$button(class = "navButton", "< zurück", onclick = "geheZurueck()"),
    tags$button(class = "navButton", "weiter >",  onclick = "geheVor()")
  ),

  # --------------------------------------------------
  # Hamburger-Menü (links)
  # --------------------------------------------------
  div(
    id = "mySidenav", class = "sidenav",
    tags$a(href="javascript:void(0)", class="closebtn", onclick="closeNav()", HTML("&times;")),
    tags$a("Start",            onclick="zeigeAktiveSektion(0); closeNav();"),
    tags$a("Einführung",       onclick="zeigeAktiveSektion(1); closeNav();"),
    tags$a("live",             onclick="zeigeAktiveSektion(2); closeNav();"),
    tags$a("Adenauer OS Tutorial", onclick="zeigeAktiveSektion(3); closeNav();"),
    tags$a("Adenauer OS",      onclick="zeigeAktiveSektion(4); closeNav();"),
    tags$a("Fahndung",         onclick="zeigeAktiveSektion(5); closeNav();"),
    tags$a("Metadaten",        onclick="zeigeAktiveSektion(6); closeNav();"),
    tags$a("Propaganda-Bots",  onclick="zeigeAktiveSektion(7); closeNav();"),
    tags$a("Statistiktok",     onclick="zeigeAktiveSektion(8); closeNav();"),
    tags$a("Zeitreihen",       onclick="zeigeAktiveSektion(9); closeNav();"),
    tags$a("Hashtag",          onclick="zeigeAktiveSektion(10); closeNav();"),
    tags$a("Contentschleuder", onclick="zeigeAktiveSektion(11); closeNav();"),
    tags$a("Hitparade",        onclick="zeigeAktiveSektion(12); closeNav();"),
    tags$a("Photo-Archiv",     onclick="zeigeAktiveSektion(13); closeNav();"),
    tags$a("Video-Archiv",     onclick="zeigeAktiveSektion(14); closeNav();"),
    tags$a("Beweisführung",    onclick="zeigeAktiveSektion(15); closeNav();"),
    tags$a("Anheuern",         onclick="zeigeAktiveSektion(16); closeNav();"),
    tags$a("Impressum",        onclick="zeigeAktiveSektion(17); closeNav();")
  ),

  # --------------------------------------------------
  # --- 18 Sektionen in exakt derselben Reihenfolge ---
  # --------------------------------------------------

  # 0) Start
  div(
    id = "section_start", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "start-flex-container",
        div(
          class = "start-image",
          img(
            src   = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/logo1.png",
            style = "width:100%; height:auto;"
          )
        ),
        div(
          class = "start-typer",
          # Zeile 1
          div(
            id = "line1Anim",
            class = "typewriter-line",
            "Projekt Tricktok",
            div(class = "typewriter-cursor")
          ),
          br(),
          br(),
          # Zeile 2
          div(
            id = "line2Anim",
            class = "typewriter-line",
            "Methode zur systematischen Erfassung, Dokumentation",
            div(class = "typewriter-cursor")
          ),
          br(),
          # Zeile 3
          div(
            id = "line3Anim",
            class = "typewriter-line",
            "und Analyse von Medien auf Tiktok.",
            div(class = "typewriter-cursor")
          )
        )
      )
    )
  ),

  # 1) Einführung (Scrollytelling)
  div(
    id = "section_intro", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        id    = "introScrollWrapper",
        class = "scrollWrapper",

        # Überschrift als schwarzer Balken (einfliegen von links)
        div(
          class = "scroll-section",
          div(
            class = "slogan-bar",
            "Demokratiefeidliche Algorithmen "
          ),
          p(class = "dummy-text",
            "..."
          )
        ),

        # Beispielbild
        img(src = "https://via.placeholder.com/800x300", class = "story-img"),

        # 1. Slogan-Balken
        div(
          class = "scroll-section",
          div(
            class = "slogan-bar",
            "Verstärkung von Ängsten in der Bevölkerung hinsichtlich einer sich verschlechternden Sicherheitslage"
          ),
          p(class = "dummy-text",
            "Lorem ipsum dolor sit amet, consectetur adipiscing elit. Nullam efficitur..."
          )
        ),

        # 2. Slogan-Balken (von rechts)
        div(
          class = "scroll-section",
          div(
            class = "slogan-bar slogan-bar-right",
            "Untergrabung des Vertrauens in staatliche Institutionen ..."
          ),
          p(class = "dummy-text",
            "Dummy-Text. Nunc scelerisque orci quis risus suscipit commodo..."
          ),
          img(src = "https://via.placeholder.com/600x400", class = "story-img")
        ),

        # 3. Slogan-Balken
        div(
          class = "scroll-section",
          div(
            class = "slogan-bar",
            "Darstellung negativer Auswirkungen politischer Entscheidungen ..."
          ),
          p(class = "dummy-text",
            "Weiterer Dummy-Text. Pellentesque habitant morbi tristique senectus..."
          )
        ),

        # 4. Slogan-Balken (von rechts)
        div(
          class = "scroll-section",
          div(
            class = "slogan-bar slogan-bar-right",
            "Stärkung euroskeptischer und extremistischer Kräfte ..."
          ),
          p(class = "dummy-text",
            "Zusätzlicher Dummy-Text. Maecenas ac libero convallis..."
          )
        ),

        # 5. Slogan-Balken
        div(
          class = "scroll-section",
          div(
            class = "slogan-bar",
            "Zuspitzung sozialer Unzufriedenheit ..."
          ),
          p(class = "dummy-text",
            "Mehr Dummy-Text. Sed non quam nec dui sodales venenatis..."
          )
        ),

        # 6. Slogan-Balken (in der Mitte)
        div(
          class = "scroll-section",
          div(
            class = "slogan-bar",
            HTML("Diskreditierung europäischer Führungspersönlichkeiten oder Regierungsparteien<br><br>Ausnutzung der staatlichen Passivität zur Öffnung weiterer Lücken in der öffentlichen Wahrnehmung.")
          ),
          p(class = "dummy-text",
            "Noch mehr Dummy-Text. Curabitur maximus sodales justo, a gravida arcu blandit a."
          )
        ),

        # 7. NEUER Slogan-Balken (von rechts)
        div(
          class = "scroll-section",
          div(
            class = "slogan-bar slogan-bar-right",
            "Die Algorythmen kuratieren deine MEinungsbildung und vergiften den demokratischen Konsens."
          ),
          p(class = "dummy-text",
            "Noch mehr Dummy-Text. Quisque tincidunt neque at dolor fermentum, in maximus nisi posuere..."
          )
        )
      )
    ),

    # Wellen-Elemente + Bildercontainer am unteren Rand der Einführung
    div(class = "wave"),
    div(class = "wave"),

    # Fünf Bilder auf Wellenhöhe (3% Größe, Movement nach jedem 3. Loop)
    div(
      class = "floating-images-container",
      div(
        class = "floating-image float1",
        tags$img(src = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/de.png")
      ),
      div(
        class = "floating-image float2",
        tags$img(src = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/tt.png")
      ),
      div(
        class = "floating-image float3",
        tags$img(src = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/afd.png")
      ),
      div(
        class = "floating-image float4",
        tags$img(src = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/ru.png")
      ),
      div(
        class = "floating-image float5",
        tags$img(src = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/usa.png")
      )
    )
  ),

  # 2) live
  div(
    id = "section_live", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://tricktok.net/")
      )
    )
  ),

  # 3) Adenauer OS Tutorial
  div(
    id = "section_adenauerosTutorial", class = "sectionBlock",
    div(
      class = "sectionContent",
      h2("Adenauer OS Tutorial (Dummy)"),
      p("Lorem ipsum tutorial content.")
    )
  ),

  # 4) Adenauer OS
  div(
    id = "section_adenaueros", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://tricktok.afd-verbot.de/")
      )
    )
  ),

  # 5) Fahndung
  div(
    id = "section_fahndung", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://tricktok.afd-verbot.de/fahndungsliste")
      )
    )
  ),

  # 6) Metadaten
  div(
    id = "section_meta", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "meta-info-block",
        img(
          src    = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-remote-beobachter/qrcode.png",
          height = "200px"
        ),
        div(
          class = "meta-info-text",
          p("Zentrale Datenbank, Automatisierter Abruf, etc.")
        )
      ),
      div(
        class = "exportButtons",
        downloadButton("download_links",      "Export Fahndungsliste"),
        downloadButton("download_metadata",   "Export Medien-Metadaten"),
        downloadButton("download_timeseries", "Export Zeitreihen")
      )
    )
  ),

  # 7) Propaganda-Bots
  div(
    id = "section_propagandaBots", class = "sectionBlock",
    div(
      class = "sectionContent",
      h2("Propaganda-Bots (Dummy)"),
      p("Lorem ipsum about bots, etc.")
    )
  ),

  # 8) Statistiktok
  div(
    id = "section_iframeExtra", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/statistiktok/")
      )
    )
  ),

  # 9) Zeitreihen
  div(
    id = "section_zeitreihen", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/zeitreihen/")
      )
    )
  ),

  # 10) Hashtag
  div(
    id = "section_hashtag", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper"
        # Beispiel: tags$iframe(src="https://tricktok.afd-verbot.de/suche/")
      )
    )
  ),

  # 11) Contentschleuder
  div(
    id = "section_medienholen", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/bilderwerfer/")
      )
    )
  ),

  # 12) Hitparade
  div(
    id = "section_hitparade", class = "sectionBlock",
    div(
      class = "sectionContent",
      h2("Hitparade (Dummy)"),
      p("Lorem ipsum for the hitparade page.")
    )
  ),

  # 13) Photo-Archiv
  div(
    id = "section_photoarchiv", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/photoarchiv/")
      )
    )
  ),

  # 14) Video-Archiv
  div(
    id = "section_videoarchiv", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://tricktok.afd-verbot.de/video_feature")
      )
    )
  ),

  # 15) Beweisführung
  div(
    id = "section_reiter2", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "iframe-wrapper",
        tags$iframe(src="https://py.afd-verbot.de/beweise/")
      )
    )
  ),

  # 16) Anheuern
  div(
    id = "section_anheuern", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "markdown-container",
        h2("Dummy-Inhalt Anheuern"),
        p("Lorem ipsum dolor sit amet, consectetur adipiscing elit.")
      )
    )
  ),

  # 17) Impressum
  div(
    id = "section_impressum", class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        class = "markdown-container",
        h2("Dummy-Inhalt Impressum"),
        p("Lorem ipsum dolor sit amet, Impressum, etc.")
      )
    )
  )
)

# -------------------------------------------------------
# Server-Logik
# -------------------------------------------------------
server <- function(input, output, session) {

  cat("[Server] Appstart. Verbindung zur DB...\n")
  dotenv::load_dot_env(".env")
  con <- dbConnect(
    Postgres(),
    dbname   = Sys.getenv("DB_NAME"),
    host     = Sys.getenv("DB_HOST"),
    port     = as.integer(Sys.getenv("DB_PORT")),
    user     = Sys.getenv("DB_USER"),
    password = Sys.getenv("DB_PASS")
  )
  onSessionEnded(function() {
    cat("[Server] Session beendet -> DB-Verbindung trennen\n")
    dbDisconnect(con)
  })

  # LIVE-Log in Navbar
  logs <- reactiveVal("")

  messagesPool <- c(
    "Verbinde zum Tricktok-Netzwerk...",
    "DB-Zugriff: Lade Mediendateien...",
    "Abfrage: Letzte Einträge aus der Datenbank...",
    "Tricktok-Apps starten...",
    "Daten aus dem Tricktok-Netzwerk werden aktualisiert..."
  )

  autoInvalidate <- reactiveTimer(2000) 
  observeEvent(autoInvalidate(), {
    oldLogs <- logs()
    newLine <- paste0("[", format(Sys.time(), "%Y-%m-%d %H:%M:%S"), "] ",
                      sample(messagesPool, 1))
    newLogs <- paste(oldLogs, newLine, sep="\n")
    logs(newLogs)
  })

  output$loadingStatus <- renderText({
    lines <- unlist(strsplit(logs(), "\n"))
    if(length(lines) > 0) {
      tail(lines, 1)
    } else {
      "Wartet auf Logs..."
    }
  })

  # 30s Cooldown
  checkCooldown <- function() {
    nowSec <- as.numeric(Sys.time())
    diff   <- nowSec - LAST_DOWNLOAD_TIME
    if(diff < COOLDOWN_SECONDS) {
      stop(
        paste0("Bitte noch ", round(COOLDOWN_SECONDS - diff),
               " Sekunden warten, bevor erneut exportiert wird!")
      )
    }
    assign("LAST_DOWNLOAD_TIME", nowSec, envir = .GlobalEnv)
  }

  # Download-Handler
  output$download_links <- downloadHandler(
    filename = function() {
      paste0("links_", Sys.Date(), ".csv")
    },
    content = function(file) {
      checkCooldown()
      df <- lade_links(con)
      write.csv(df, file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )

  output$download_metadata <- downloadHandler(
    filename = function() {
      paste0("media_metadata_", Sys.Date(), ".csv")
    },
    content = function(file) {
      checkCooldown()
      df <- lade_media_metadata(con)
      write.csv(df, file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )

  output$download_timeseries <- downloadHandler(
    filename = function() {
      paste0("media_time_series_", Sys.Date(), ".csv")
    },
    content = function(file) {
      checkCooldown()
      df <- lade_media_time_series(con)
      write.csv(df, file, row.names=FALSE, fileEncoding="UTF-8")
    }
  )
}

cat("==== Starting shinyApp ====\n")
shinyApp(
  ui = ui,
  server = server,
  options = list(
    host           = "0.0.0.0",
    port           = 4040,
    launch.browser = FALSE
  )
)
