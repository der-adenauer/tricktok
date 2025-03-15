#!/usr/bin/env Rscript
# -*- coding: utf-8 -*-

# ==================================================
# Shiny-App:
#   - Navigation über < zurück / weiter >
#   - Navbar (Top-Bar) sticky oben
#   - Hamburger-Menü von links
#   - Reload-Button und Logo rechts
#   - Keine globalen Scrollbalken (Overflow: hidden)
#   - Metadaten / Anheuern / Impressum: Text im Blocksatz
#   - Wechselanimation: nächste Seite fällt von oben herab (SlideDown)
#   - In den meisten Sektionen 10% Abstand (links/rechts)
#   - Fahndungsliste / Contentschleuder: Vollbild (unterhalb Top-Bar)
#   - 30s Cooldown für alle CSV-Downloads
#   - Startseite: nur noch ein iframe (alles andere auf Startseite entfernt)
#   - Bilder (Einführung) kombinieren horizontale und wellenförmige Bewegung
#   - In der Metadaten-Sektion (section_meta):
#       * Schwarzer Balken (oben)
#       * QR-Code + Buttons
#       * Ein weiterer schwarzer Balken unter den Buttons
#       * Scroll-Wrapper
#       * Storytelling-Komponente mit Slogans / Zitaten wie in Einführung
#   - Ehemalige Propaganda-Bots-Sektion heißt jetzt „Tricktok-Tutorial“
#       * Schwarzer Balken
#       * Scrollytelling (Slogans / Zitate)
#       * Zweispaltiger Textabschnitt
#   - Neue Sektion „Propaganda-Kanäle“ direkt hinter Tricktok-Tutorial
#   - Reihenfolge der Sektionen:
#       0)  Start
#       1)  Einführung
#       2)  live
#       5)  Fahndung
#       6)  Metadaten
#       7)  Tricktok-Tutorial (vormals Propaganda-Bots)
#       8)  Propaganda-Kanäle
#       9)  Statistiktok
#       10) Zeitreihen
#       11) Contentschleuder
#       12) Jukebox (ehem. Hitparade)
#       13) Photo-Archiv
#       14) Beweisführung
#       15) Anheuern
#       16) Impressum
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
# Benutzeroberfläche mit Lazy-Loading-Logik pro Sektion
# -------------------------------------------------------
ui <- fluidPage(
  style = "margin:0; padding:0;",

  tags$head(
    tags$meta(
      name = "viewport",
      content = "width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no"
    ),

    # --------------------------------
    # JavaScript: Navigation + Menü-Steuerung + Lazy Loading
    # --------------------------------
    tags$script(HTML("
      var currentSectionIndex = 0;
      var sections = [];
      // Reihenfolge / Titel (Index 5: Tricktok-Tutorial)
      var sectionTitles = [
        'Start',
        'Einführung',
        'live',
        'Fahndung',
        'Metadaten',
        'Tricktok-Tutorial',
        'Propaganda-Kanäle',
        'Statistiktok',
        'Zeitreihen',
        'Contentschleuder',
        'Jukebox',
        'Photo-Archiv',
        'Beweisführung',
        'Anheuern',
        'Impressum'
      ];

      function openNav(){
        var sn = document.getElementById('sideNav');
        if(sn) sn.style.width = '250px';
      }
      function closeNav(){
        var sn = document.getElementById('sideNav');
        if(sn) sn.style.width = '0';
      }
      document.addEventListener('click', function(e){
        var sidenav = document.getElementById('sideNav');
        var hamburgerBtn = document.getElementById('hamburgerBtn');
        if(sidenav && hamburgerBtn && !sidenav.contains(e.target) && !hamburgerBtn.contains(e.target)){
          closeNav();
        }
      });

      document.addEventListener('DOMContentLoaded', function(){
        sections = document.getElementsByClassName('sectionBlock');
        zeigeAktiveSektion(0); // Standard: Start
      });

      function zeigeAktiveSektion(index){
        if(index < 0 || index >= sections.length){ return; }

        // Alle iframes in allen Sektionen entladen (src -> about:blank)
        for(var i=0; i<sections.length; i++){
          var iframes = sections[i].getElementsByTagName('iframe');
          for(var j=0; j<iframes.length; j++){
            iframes[j].setAttribute('src', 'about:blank');
          }
          sections[i].classList.remove('activeSection');
        }

        // Gewählte Sektion aktivieren
        sections[index].classList.add('activeSection');

        // Iframes in aktiver Sektion laden (data-src -> src)
        var activeIframes = sections[index].getElementsByTagName('iframe');
        for(var j=0; j<activeIframes.length; j++){
          var dataSrc = activeIframes[j].getAttribute('data-src');
          if(dataSrc){
            activeIframes[j].setAttribute('src', dataSrc);
          }
        }

        var heading = document.getElementById('currentHeading');
        if(heading && sectionTitles[index]){
          heading.textContent = sectionTitles[index];
        }
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
        overflow: hidden; 
        font-family: sans-serif;
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
        display: flex; align-items: center; gap: 10px;
      }
      .topBarRight {
        display: flex; align-items: center; gap: 10px;
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
        overflow: hidden;
      }
      .sectionBlock.activeSection {
        visibility: visible; 
        opacity: 1; 
        transform: translateY(0);
      }

      .sectionContent {
        margin: 0 10%;
        height: calc(100%);
        text-align: left;
        padding: 0;
      }
      @media (max-width: 768px) {
        .sectionContent {
          margin: 0 3%;
        }
      }

      #section_fahndung    { background-color: #ccc; }
      #section_medienholen { background-color: #ccc; }

      #section_fahndung   .sectionContent,
      #section_medienholen .sectionContent {
        margin: 0; 
        padding: 0; 
        width: 100%; 
        height: 100%;
      }
      #section_fahndung .iframe-wrapper,
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

      /* STARTSEITE: Nur ein iframe */
      #section_start .sectionContent {
        display: flex;
        flex-direction: column;
        justify-content: center;
        align-items: stretch; 
      }

      /* Einführungsbilder: Wellenbewegung */
      #section_intro { background-color: #fff; position: relative; }
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
      .wave:nth-of-type(2) {
        opacity: 0.7;
        animation: swell 5s ease -1.25s infinite,
                   wave 5s cubic-bezier(0.36, 0.45, 0.63, 0.53) -.125s infinite;
        z-index: 0;
      }
      @keyframes wave {
        0%   { background-position-x: 0%; }
        100% { background-position-x: -500px; }
      }
      @keyframes swell {
        0%, 100% {
          background-position: right bottom 10px;
        }
        50% {
          background-position: right bottom 0;
        }
      }

/* --- An anderen Stellen unverändert, aber das hier bitte ersetzen/ergänzen --- */

/* Der Einführungsabschnitt (#section_intro) erlaubt Overflow, 
   damit die Bilder oben/unten nicht abgeschnitten werden */
#section_intro {
  overflow: visible !important;  /* wichtig, sonst 'overflow:hidden' */
  position: relative;            /* Kinder (floating-images-container) können absolut sein */
}

/* Container für die Bilder, positioniert über den Wellen */
.floating-images-container {
  position: absolute;
  bottom: 660px;   /* je nach gewünschter Höhe */
  left: 0;
  width: 100%;
  height: 0;
  pointer-events: none;
  z-index: 5;      /* höher als wave (z-index:1 oder 0) */
}

/* Anfangszustand: display:none (später per JS auf 'block' gesetzt) */
.floating-image {
  position: absolute;
  display: none;
  width: auto;
  height: auto;
  transform: scale(0.43); /* Skalierung Desktop */
}

/* Desktop-Keyframes: 25s, von rechts außerhalb (right:-40%) 
   nach links außerhalb (right:140%), 
   zwischendrin leichte Wellenbewegung */
@keyframes moveHorizontallyDesktop {
  0% {
    right: -40%;
    transform: translateY(0) scale(0.43);
  }
  25% {
    transform: translateY(-50px) scale(0.43);
  }
  50% {
    transform: translateY(0) scale(0.43);
  }
  75% {
    transform: translateY(-40px) scale(0.43);
  }
  100% {
    right: 140%;
    transform: translateY(0) scale(0.43);
  }
}

/* Mobile-Keyframes: 15s, weiter außen starten (z. B. -60%) / enden (160%). 
   Auch weniger Vertikalbewegung, wenn gewünscht. */
@keyframes moveHorizontallyMobile {
  0% {
    right: -160%;
    transform: translateY(0) scale(0.35);
  }
  25% {
    transform: translateY(-35px) scale(0.35);
  }
  50% {
    transform: translateY(0) scale(0.35);
  }
  75% {
    transform: translateY(-25px) scale(0.35);
  }
  100% {
    right: 160%;
    transform: translateY(0) scale(0.35);
  }
}

/* Standard-Fall (Desktop): 15s, Keyframes moveHorizontallyDesktop */
.moveFromRight {
  animation: moveHorizontallyDesktop 15s cubic-bezier(0.36, 0.45, 0.63, 0.53) forwards;
}

/* Mobile-Anpassungen per Media Query:
   - andere Keyframes
   - andere Dauer (z. B. 15s)
*/
@media (max-width: 768px) {
  .moveFromRight {
    animation: moveHorizontallyMobile 15s cubic-bezier(0.36, 0.45, 0.63, 0.53) forwards;
  }
}


      /* Scrollytelling-Effekte */
      .scrollWrapper {
        width: 100%;
        height: 100%;
        overflow-y: auto;
        box-sizing: border-box;
        padding-bottom: 40px;
        -ms-overflow-style: none;
        scrollbar-width: none;
      }
      .scrollWrapper::-webkit-scrollbar {
        width: 0px;
        background: transparent;
      }
      .scroll-section {
        width: 100%;
        min-height: 10vh;
        padding: 40px;
        box-sizing: border-box;
      }
      .slogan-bar {
        background-color: #000;
        color: #fff;
        font-size: 2.5em;
        font-weight: bold;
        padding: 20px;
        margin: 40px 0;
        opacity: 1;
        transform: translateX(0);
        transition: none;
        white-space: normal;
        word-break: break-word;
        overflow: hidden;
        text-align: left;
        max-width: 100%;
      }
      .slogan-bar-right {
        transform: translateX(100vw);
        transition: all 1s ease;
        text-align: right;
        opacity: 0;
      }
      .slogan-bar.show {
        opacity: 1;
        transform: translateX(0);
      }
      .quote-left, .quote-right {
        font-size: 2.0em;
        margin: 30px 0;
        opacity: 0;
        transition: all 1s ease;
        max-width: 90%;
        line-height: 1.2;
        font-family: Georgia, serif;
      }
      .quote-left {
        text-align: left;
        transform: translateX(-50vw);
      }
      .quote-right {
        text-align: right;
        transform: translateX(100vw);
      }
      .quote-left.show, .quote-right.show {
        opacity: 1;
        transform: translateX(0);
      }
      .quote-citation {
        font-size: 0.6em;
        opacity: 0.8;
        margin-top: 10px;
        display: block;
      }
      .hover-word {
        position: relative;
        cursor: help;
        text-decoration: underline dotted #666;
      }
      .hover-word:hover::after {
        content: attr(data-hover);
        position: absolute;
        top: 120%;
        left: 0;
        background-color: rgba(0,0,0,0.85);
        color: #fff;
        padding: 10px;
        border-radius: 5px;
        width: 650px;
        font-size: 0.8em;
        box-shadow: 0 2px 4px rgba(0,0,0,0.4);
        pointer-events: none;
        white-space: normal;
        word-break: break-word;
        opacity: 1;
        z-index: 200;
      }
      .hover-word::after {
        opacity: 0;
        transition: all 0.3s;
      }

      .two-column-container {
        display: flex; 
        flex-wrap: wrap; 
        gap: 20px;
      }
      .two-column-container > div {
        flex: 1; 
        min-width: 200px; 
        max-width: 50%;
      }
    ")),

    # --------------------------------
    # JS: Scrollytelling-Effekte
    # --------------------------------
tags$script(HTML("
  function checkSloganBars(){
    var elements = document.querySelectorAll('.slogan-bar-right, .quote-left, .quote-right');
    for (var i = 0; i < elements.length; i++) {
      var rect = elements[i].getBoundingClientRect();
      var windowHeight = window.innerHeight || document.documentElement.clientHeight;
      if (rect.top <= windowHeight - 100 && rect.bottom >= 0) {
        elements[i].classList.add('show');
      }
    }
  }

 document.addEventListener('DOMContentLoaded', function(){
  // 1) Scrollytelling-Effekte wie gehabt (Intro, Meta, Tutorial)
  var scrollWrapper = document.getElementById('introScrollWrapper');
  if(scrollWrapper){
    scrollWrapper.addEventListener('scroll', checkSloganBars);
    setTimeout(function(){ checkSloganBars(); }, 200);
  }

  var metaScrollWrapper = document.getElementById('metaScrollWrapper');
  if(metaScrollWrapper){
    metaScrollWrapper.addEventListener('scroll', checkSloganBars);
    setTimeout(function(){ checkSloganBars(); }, 200);
  }

  var tutorialScrollWrapper = document.getElementById('tricktokTutorialScrollWrapper');
  if(tutorialScrollWrapper){
    tutorialScrollWrapper.addEventListener('scroll', checkSloganBars);
    setTimeout(function(){ checkSloganBars(); }, 200);
  }

  // 2) Floating Images: Unabhängig von Wellen. 
  var floatingImages = document.querySelectorAll('.floating-image');
  var imageIndex = 0;

  // Optional: direkt erstes Bild starten
  triggerNextImage();

  // Alle 25s ein neues Bild anstoßen (Flug)
  setInterval(triggerNextImage, 12000);

  function triggerNextImage() {
    // Alle Bilder unsichtbar machen
    for(var i=0; i<floatingImages.length; i++){
      floatingImages[i].style.display = 'none';
      floatingImages[i].classList.remove('moveFromRight');
    }
    // Nächstes Bild anzeigen + Animation triggern
    var img = floatingImages[imageIndex];
    img.style.display = 'block';
    // Reflow Trick
    void img.offsetWidth;
    img.classList.add('moveFromRight');

    // Weiter zum nächsten
    imageIndex = (imageIndex + 1) % floatingImages.length;
  }
});

"))

  ),

  # --------------------------------------------------
  # Obere Leiste (Top-Bar)
  # --------------------------------------------------
  div(
    class = "topBar",
    div(
      class = "topBarLeft",
      tags$button(id="hamburgerBtn", HTML("&#9776;"), onclick="openNav()"),
      div(id="currentHeading", "Start")
    ),
    div(
      class = "topBarRight",
      div(class="reloadIcon", HTML("&#x21bb;"), onclick="location.reload();"),
      tags$img(
        id="logoImage",
        src="https://politicalbeauty.de/assets/images/politische-schoenheit-logo-2023.svg"
      )
    )
  ),

  # --------------------------------------------------
  # Navigation unten rechts (< zurück / weiter >)
  # --------------------------------------------------
  div(
    class = "navButtons",
    tags$button(class="navButton", "< zurück", onclick="geheZurueck()"),
    tags$button(class="navButton", "weiter >", onclick="geheVor()")
  ),

  # --------------------------------------------------
  # Hamburger-Menü (links)
  # --------------------------------------------------
  div(
    id="sideNav", class="sidenav",
    tags$a(href="javascript:void(0)", class="closebtn", onclick="closeNav()", HTML("&times;")),

    tags$a("Start",             onclick="zeigeAktiveSektion(0); closeNav();"),
    tags$a("Einführung",        onclick="zeigeAktiveSektion(1); closeNav();"),
    tags$a("live",              onclick="zeigeAktiveSektion(2); closeNav();"),
    tags$a("Fahndung",          onclick="zeigeAktiveSektion(3); closeNav();"),
    tags$a("Metadaten",         onclick="zeigeAktiveSektion(4); closeNav();"),
    tags$a("Tricktok-Tutorial", onclick="zeigeAktiveSektion(5); closeNav();"),
    tags$a("Propaganda-Kanäle", onclick="zeigeAktiveSektion(6); closeNav();"),
    tags$a("Statistiktok",      onclick="zeigeAktiveSektion(7); closeNav();"),
    tags$a("Zeitreihen",        onclick="zeigeAktiveSektion(8); closeNav();"),
    tags$a("Contentschleuder",  onclick="zeigeAktiveSektion(9); closeNav();"),
    tags$a("Jukebox",           onclick="zeigeAktiveSektion(10); closeNav();"),
    tags$a("Photo-Archiv",      onclick="zeigeAktiveSektion(11); closeNav();"),
    tags$a("Beweisführung",     onclick="zeigeAktiveSektion(12); closeNav();"),
    tags$a("Anheuern",          onclick="zeigeAktiveSektion(13); closeNav();"),
    tags$a("Impressum",         onclick="zeigeAktiveSektion(14); closeNav();")
  ),

  # --------------------------------------------------
  # Sektionen
  # --------------------------------------------------

  # 0) Start
  div(
    id="section_start", 
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="iframe-wrapper",
        # Lazy Loading: data-src statt src
        tags$iframe(
          `data-src` = "https://py.afd-verbot.de/freefall",
          src = "about:blank"
        )
      )
    )
  ),

  # 1) Einführung
  div(
    id = "section_intro", 
    class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        id = "introScrollWrapper", 
        class = "scrollWrapper",


          div(
          class="start-image",
          img(
            src   = "https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/logo1.png",
            style = "width: 400px; height: auto; display: block; margin: 0 auto;"
          )
        ),

        div(
          style = "
            margin-bottom: 20px; 
            background-color: #000; 
            color: #fff; 
            font-size: 2.5em; 
            font-weight: bold; 
            padding: 20px; 
            white-space: normal; 
            word-break: break-word;
          ",
          "Demokratiefeindliche Algorithmen vergiften politische Meinungsbildung"
        ),

        div(
          class = "quote-left show",
          "\"Tiktok´s Wertemodell bestehend aus:\" ", br(),
          "\"用户价值, 作者价值, 平台价值, and 间接价值.\"",
          br(),
          HTML(paste0(
            "\"",
            "<span class='hover-word' data-hover='Wert für den Nutzer (Verweildauer, Zufriedenheit)'>Benutzerwert</span>", ", ",
            "<span class='hover-word' data-hover='Wert für den Videoersteller (Reichweite, Interaktionen, Einnahmen)'>Autorenwert</span>", ", ",
            "<span class='hover-word' data-hover='Nutzen für die Plattform (Markenwirkung, Sicherheit, Einnahmen)'>Plattformwert</span>",
            " und ",
            "<span class='hover-word' data-hover='Späte oder indirekte Effekte (Kommentarerwähnungen, Benachrichtigungen, weitere Interaktionen)'>Indirekter Wert</span>",
            ".\""
          )),
          span(class = "quote-citation", "- Algo 101 , Bytedance , Peking ")
        ),

                  div(
            class = "quote-right show",
            "\".. kennt keine keine demokratischen Werte \"",
          
          ),
        

          

        div(
          class = "scroll-section",
          div(
            class = "slogan-bar",
            "Verstärkung von Ängsten in der Bevölkerung hinsichtlich einer sich verschlechternden Sicherheitslage"
          ),
          div(
            class = "quote-left",
            "\"But if your democracy can be destroyed with a few hundred thousand dollars of digital advertising from a foreign country, then it wasn’t very strong to begin with. \"",
            span(class = "quote-citation", "- J.D Vance, 2025 in München")
          )
        ),

        div(
          class = "scroll-section",
          div(
            class="slogan-bar slogan-bar-right",
            "Untergrabung des Vertrauens in staatliche Institutionen."
          ),
          div(
            class="quote-right",
            "\"Only the AfD can save germany.\"",
            span(class="quote-citation", "- Elon Musk, Dezember 2024 x.com")
          )
        ),

        div(
          class = "scroll-section",
          div(
            class = "slogan-bar slogan-bar-right",
            "Stärkung euroskeptischer und extremistischer Kräfte ..."
          ),
          div(
            class = "quote-right",
            "\"Der größte Erfolg nach dieser schrecklichen Ära unserer Geschichte war es, Adolf Hitler als rechts und konservativ zu bezeichnen. Er war das genaue Gegenteil. Er war nicht konservativ. Er war dieser sozialistisch-kommunistische Typ.\"",
            span(class="quote-citation", "- Alice Weidel, 2025 in der Videokonferenz")
          )
        ),

        div(
          class = "scroll-section",
          style = "margin: 10px 0;",
          div(
            class = "slogan-bar",
            "Darstellung negativer Auswirkungen politischer Entscheidungen auf die soziale und wirtschaftliche Situation"
          ),
          p("bäm bäm bäm!", style="color:#666; margin-top:10px; font-weight:bold;")
        ),

        div(
          class = "scroll-section",
          style = "margin: 10px 0;",
          div(
            class = "slogan-bar",
            "Zuspitzung sozialer Unzufriedenheit."
          )
        ),
        div(
          class = "scroll-section",
          style = "margin: 10px 0;",
          div(
            class = "slogan-bar",
            HTML("Diskreditierung europäischer Führungspersönlichkeiten oder Regierungsparteien.")
          )
        ),
        div(
          class = "scroll-section",
          style = "margin: 10px 0;",
          div(
            class = "slogan-bar",
            HTML("Ausnutzung der staatlichen Passivität zur Öffnung weiterer Lücken in der öffentlichen Wahrnehmung.")
          )
        ),

      )
    ),
    div(class="wave"),
    div(class="wave"),
    div(
      class="floating-images-container",
      div(
        class="floating-image float1", 
        tags$img(src="https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/de.png")
      ),
      div(
        class="floating-image float2", 
        tags$img(src="https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/tt.png")
      ),
      div(
        class="floating-image float3", 
        tags$img(src="https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/afd.png")
      ),
      div(
        class="floating-image float4", 
        tags$img(src="https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/ru.png")
      ),
      div(
        class="floating-image float5", 
        tags$img(src="https://raw.githubusercontent.com/der-adenauer/tricktok/refs/heads/main/tt-R/www/usa.png")
      )
    )
  ),

  # 2) live
  div(
    id="section_live", 
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="iframe-wrapper",
        tags$iframe(`data-src`="https://tricktok.net/", src="about:blank")
      )
    )
  ),

  # 5) Fahndung
  div(
    id="section_fahndung", 
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="iframe-wrapper",
        tags$iframe(`data-src`="https://tricktok.afd-verbot.de/fahndungsliste", src="about:blank")
      )
    )
  ),

# 6) Metadaten
div(
  id = "section_meta",
  class = "sectionBlock",
  div(
    class = "sectionContent",
    div(
      id = "metaScrollWrapper",
      class = "scrollWrapper",



              div(
        style = "
          margin-bottom: 15px; 
          background-color: #000; 
          color: #fff;
          font-size: 2.5em; 
          font-weight: bold;
          padding: 15px; 
          white-space: normal; 
          word-break: break-word;
        ",
        "Tricktok-Metadaten"
      ),




                              p(
        style = "
          margin-bottom: 45px; 
          font-size: 1.2em; 
          line-height: 1.3;
        ",
        "Tricktok ist eine dezentrale, community-basierte Plattform zur Aufdeckung manipulativer Social-Media-Inhalte und um Eingriffe in die europäische Wertegemeinschaft zu identifizieren."
      ),




      # -- Oberer schwarzer Balken: Tricktok-Metadaten-Download
      div(
        style = "
          margin-bottom: 15px; 
          background-color: #000; 
          color: #fff;
          font-size: 2.5em; 
          font-weight: bold;
          padding: 15px; 
          white-space: normal; 
          word-break: break-word;
        ",
        "Tricktok-Metadaten-Download"
      ),

                    # -- Kurze Einleitung
      div(
        class = "quote-right",
        style = "
          font-size: 2.0em; 
          font-weight: bold;
          margin-bottom: 15px;
          color: #000;
        ",
        "Tricktok Datensatz Größe ca. 3.6 GB"
      ),


      # -- QR-Code + Export-Buttons
      div(
        style = "margin: 15px 0; display: flex; align-items: flex-start; gap: 20px;",
        img(
          src = "",
          height = "200px"
        ),


  
          
        div(
          style = "flex: 1;",
          br(),
          div(
            class = "exportButtons",
            style = "display: flex; flex-direction: column; gap: 10px;",
            downloadButton("download_links",      "Export Fahndungsliste"),
            downloadButton("download_metadata",   "Export Medien-Metadaten"),
            downloadButton("download_timeseries", "Export Zeitreihen")
          ),
          br()
        )
      ),

      # -- Kurze Einleitung
      div(
        class = "quote-left",
        style = "
          font-size: 2.0em; 
          font-weight: bold;
          margin-bottom: 15px;
          color: #000;
        ",
        "Tricktok ist OPENDATA"
      ),



      p(
        style = "
          margin-bottom: 15px; 
          font-size: 1.2em; 
          line-height: 1.3;
        ",
        "Bietet Zugang zu gesammelten Metadaten 
         für Interessierte und Forschende in digitaler Gesellschaft. 
         Ermöglicht dezentrale Analyse und Austausch von Arbeitsergebnissen, 
         um Manipulationsmuster auf Tiktok besser zu verstehen."
      ),



      # -- Slogan-Balken: Werde Analyst/in ...
      div(
        class = "scroll-section",
        style = "margin: 20px 0;",
        div(
          class = "slogan-bar",
          "Werde Analyst/in beim Zentrum für politische Schönheit"
        )
      ),
      div(
        class = "quote-left",
        style = "margin-bottom: 10px;",
        "Verantwortungsvolle Position mit Fokus auf gesellschaftliche Herausforderungen",
        span(class="quote-citation", "Setze zur Impulse")
      ),

      div(
        class = "quote-left",
        style = "margin-bottom: 10px;",
        "100 % Remote mit Gleitzeit",
        span(class="quote-citation", "Keine Zeiterfassung")
      ),
      div(
        class = "quote-left",
        style = "margin-bottom: 10px;",
        "Ausgestattet mit den besten Methoden unserer Zeit.",
        span(class="quote-citation", "Verwende KI-Technologien in Bild, Ton und Text")
      ),  

      div(
        class = "quote-right",
        style = "margin-bottom: 10px;",
        "JETZT bewerben!",
        span(class="quote-citation", "adenauer@tutamail.com")
      ),

      p(
        style = "margin: 10px 0;",
        "..."
      ),




           # -- Neuer Slogan-Balken: Hilf bei ...
      div(
        class = "scroll-section",
        style = "margin: 20px 0;",
        div(
          class = "slogan-bar",
          "Hilf bei der Erkennung von Wahl-beeinflussung, Hass und Falschrede."
        ),
        # Einzelne Quotes
        div(
          class = "quote-left",
          style = "margin-bottom: 10px;",
          "Verfolge die Verbreitung falscher Informationen.",
          span(class = "quote-citation", "Ermittele deren Ursprung.")
        ),
        div(
          class = "quote-left",
          style = "margin-bottom: 10px;",
          "Indentifiziere automatisierte Accounts (Bots)",
          span(class = "quote-citation", "Erkenne die Muster.")
        ),
        div(
          class = "quote-left",
          style = "margin-bottom: 10px;",
          "Besuche meinungsverstärkende Echokammern.",
          span(class = "quote-citation", "Mensch, ärgere dich nicht!")
        ),
        div(
          class = "quote-left",
          style = "margin-bottom: 10px;",
          "Analysiere virale Trends",
          span(class = "quote-citation", "Verstehe die modernen Mechanismen schneller Verbreitung von Inhalten.")
        ),
        div(
          class = "quote-left",
          style = "margin-bottom: 10px;",
          "Erforsche manipulative Engagement-Strategien",
          span(class = "quote-citation", "Verstehe dein eigenes Nutzungsverhalten.")
        )
      )
     ,






        

      # -- Slogan-Balken: Europaweite Offensive
      div(
        class = "scroll-section",
        style = "margin: 20px 0;",
        div(
          class = "slogan-bar",
          "Tricktok Europatour"
        ),


              div(
        class = "scroll-section",
        style = "margin: 20px 0;",
        div(
          class = "quote-right",
          style = "margin-bottom: 10px;",
          "Hilf uns Wahlbeeinflussung auf europäischer Ebene zu indentifizieren. ",
          span(class="quote-citation", "- ZpS-Lab")
        )
      ),

        # -----------------------------
        # Große EU-Wahlliste / Tabelle (jetzt zentriert)
        # -----------------------------
        HTML("
<div style='margin-top:20px;'>
  <style>
    .mini-table {
      width: 100%;
      border-collapse: collapse;
      font-family: Arial, sans-serif;
      margin-bottom: 20px;
    }
    .mini-table thead tr {
      background-color: #f0f0f0;
    }
    .mini-table th,
    .mini-table td {
      border: 1px solid #ccc;
      padding: 8px;
      text-align: center; /* Zentrierung */
      vertical-align: middle;
    }
    .mini-table tbody tr:nth-child(even) {
      background-color: #fafafa;
    }
    .flag {
      font-size: 1.5em; /* Flaggen in größerer Schriftgröße */
      margin-right: 6px;
    }
  </style>

  <table class='mini-table'>
    <thead>
      <tr>
        <th style='width:40%;'>Land / Datum</th>
        <th>Wahl/Abstimmung</th>
      </tr>
    </thead>
    <tbody>
      <!-- Österreich -->
      <tr>
        <td>
          <span class='flag'>&#127462;&#127481;</span>Österreich<br>
          27. Apr.
        </td>
        <td>Landtags- und Gemeinderatswahl in Wien</td>
      </tr>
      <tr>
        <td>
          <span class='flag'>&#127462;&#127481;</span>Österreich<br>
          27. Apr.
        </td>
        <td>Bezirksvertretungswahl in Wien</td>
      </tr>

      <!-- Vereinigtes Königreich -->
      <tr>
        <td>
          <span class='flag'>&#127468;&#127463;</span>Vereinigtes Königreich<br>
          1. Mai
        </td>
        <td>Kommunalwahlen im Vereinigten Königreich</td>
      </tr>

      <!-- Rumänien -->
      <tr>
        <td>
          <span class='flag'>&#127479;&#127476;</span>Rumänien<br>
          4. Mai
        </td>
        <td>Präsidentschaftswahl in Rumänien</td>
      </tr>

      <!-- Albanien -->
      <tr>
        <td>
          <span class='flag'>&#127462;&#127465;</span>Albanien<br>
          11. Mai
        </td>
        <td>Parlamentswahl in Albanien</td>
      </tr>

      <!-- Polen -->
      <tr>
        <td>
          <span class='flag'>&#127477;&#127473;</span>Polen<br>
          18. Mai
        </td>
        <td>Präsidentschaftswahl in Polen</td>
      </tr>

      <!-- Lettland -->
      <tr>
        <td>
          <span class='flag'>&#127473;&#127483;</span>Lettland<br>
          7. Jun.
        </td>
        <td>Kommunalwahlen in Lettland</td>
      </tr>

      <!-- Norwegen -->
      <tr>
        <td>
          <span class='flag'>&#127475;&#127476;</span>Norwegen<br>
          8. Sep.
        </td>
        <td>Parlamentswahl in Norwegen</td>
      </tr>

      <!-- Deutschland -->
      <tr>
        <td>
          <span class='flag'>&#127465;&#127466;</span>Deutschland<br>
          14. Sep.
        </td>
        <td>Kommunalwahlen in Nordrhein-Westfalen</td>
      </tr>

      <!-- Georgien -->
      <tr>
        <td>
          <span class='flag'>&#127468;&#127466;</span>Georgien<br>
          Oktober
        </td>
        <td>Kommunalwahlen in Georgien</td>
      </tr>

      <!-- Irland -->
      <tr>
        <td>
          <span class='flag'>&#127470;&#127466;</span>Irland<br>
          Oktober
        </td>
        <td>Präsidentschaftswahl in Irland</td>
      </tr>

      <!-- Tschechien -->
      <tr>
        <td>
          <span class='flag'>&#127464;&#127487;</span>Tschechien<br>
          Oktober
        </td>
        <td>Abgeordnetenhauswahl in Tschechien</td>
      </tr>
    </tbody>
  </table>
</div>
")
      ),



      # -- Weiterer Slogan
div(
  class = "scroll-section",
  style = "margin: 20px 0;",
  
  div(
    class = "slogan-bar slogan-bar-right",
    "Tricktok ist Open-Source."
  ),
  
  div(
    class = "quote-left",
    style = "margin-bottom: 10px;",
    "Installiere eine Tricktok-Instanz in deinem EU-Staat",
    span(class="quote-citation", "")
  ),
  
  # Hier das Bild der Tabelle einfügen
#  img(
#    src    = "DEIN-BILD-URL.png",  # Ersetze mit der richtigen Bild-URL
#    height = "400px"
#  ),




      ),


      
      div(
        class = "scroll-section",
        style = "margin: 20px 0;",
        div(
          class = "slogan-bar",
          "Gestalte wehrhafte Digitalpolitik"
        ),
        div(
          class = "quote-left",
          style = "margin-bottom: 10px;",
          "Sei dabei.",
          span(class="quote-citation", "")
        )
      ),


    )
  )
)
,

  # 7) Tricktok-Tutorial (vormals Propaganda-Bots)
  div(
    id="section_tricktokTutorial",
    class="sectionBlock",
    div(
      class = "sectionContent",
      div(
        id = "tricktokTutorialScrollWrapper",
        class = "scrollWrapper",

        div(
          style = "
            margin-bottom: 20px; 
            background-color: #000; 
            color: #fff;
            font-size: 2.0em; 
            font-weight: bold;
            padding: 20px; 
            white-space: normal; 
            word-break: break-word;
          ",
          "Tricktok-Tutorial"
        ),

        div(
        style = "
          font-size: 1.2em;
          line-height: 1.3;
          margin-bottom: 15px;
        ",
        p("Tiktok-Kanäle:"),
        tags$ul(
          tags$li("."),
          tags$li("Atlhen."),
          tags$li("ung."),
          tags$li("eitung."),
          tags$li("Eten.")
        )
      ),

        div(
          class = "scroll-section",
          style = "margin: 40px 0;",
          div(
            class = "slogan-bar",
            "..."
          ),
          div(
            class = "quote-right",
            "\"...\"",
            span(class="quote-citation", " - ...")
          )
        ),
        div(
          class = "scroll-section",
          style = "margin: 40px 0;",
          div(
            class = "slogan-bar slogan-bar-right",
            "..."
          ),
          div(
            class = "quote-left",
            "\"...\"",
            span(class="quote-citation", "- ...")
          )
        ),

        div(
          class = "scroll-section",
          style = "margin: 40px 0;",
          div(
            class = "slogan-bar",
            "Step-by-Step Anregungen"
          ),
          div(
            class = "two-column-container",
            div(
              tags$p("
                ...
              ")
            ),
            div(
              tags$p("
                ...
              ")
            )
          )
        ),

        div(
          class = "scroll-section",
          style = "margin: 40px 0;",
          div(
            class = "slogan-bar slogan-bar-right",
            "Selbstexperiment: Eigenes Tiktok-Profil"
          ),
          div(
            class = "quote-left",
            "\"...\"",
            span(class="quote-citation", "- ...")
          )
        )
      )
    )
  ),

  # 8) Propaganda-Kanäle
  div(
    id = "section_propagandaKanaele",
    class = "sectionBlock",
    div(
      class = "sectionContent",
      div(
        style = "height:100%; overflow-y:auto; padding: 20px;",
        div(
          class="iframe-wrapper",
          tags$iframe(`data-src`="https://py.afd-verbot.de/kanalraster/", src="about:blank")
        )
      )
    )
  ),

  # 9) Statistiktok
  div(
    id="section_iframeExtra",
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="iframe-wrapper",
        tags$iframe(`data-src`="https://py.afd-verbot.de/statistiktok/", src="about:blank")
      )
    )
  ),

  # 10) Zeitreihen
  div(
    id="section_zeitreihen",
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="iframe-wrapper",
        tags$iframe(`data-src`="https://py.afd-verbot.de/zeitreihen/", src="about:blank")
      )
    )
  ),

  # 11) Contentschleuder
  div(
    id="section_medienholen",
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="iframe-wrapper",
        tags$iframe(`data-src`="https://py.afd-verbot.de/bilderwerfer/", src="about:blank")
      )
    )
  ),

  # 12) Jukebox (Hitparade)
  div(
    id="section_hitparade",
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="iframe-wrapper",
        tags$iframe(`data-src`="https://py.afd-verbot.de/jukebox/", src="about:blank")
      )
    )
  ),

  # 13) Photo-Archiv
  div(
    id="section_photoarchiv",
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="iframe-wrapper",
        tags$iframe(`data-src`="https://py.afd-verbot.de/photoarchiv/", src="about:blank")
      )
    )
  ),

  # 14) Beweisführung
  div(
    id="section_reiter2",
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="iframe-wrapper",
        tags$iframe(`data-src`="https://py.afd-verbot.de/beweise/", src="about:blank")
      )
    )
  ),

  # 15) Anheuern
  div(
    id="section_anheuern",
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="markdown-container",
        h2("Anheuern"),
        p("Weitere Informationen per Mail an adenauer@tutamail.com.")
      )
    )
  ),

  # 16) Impressum
  div(
    id="section_impressum",
    class="sectionBlock",
    div(
      class="sectionContent",
      div(
        class="markdown-container",
        h2("Impressum"),
        p("Kontaktinformationen und rechtliche Hinweise unter https://politicalbeauty.de/")
      )
    )
  )
)

# -------------------------------------------------------
# Server-Logik
# -------------------------------------------------------
server <- function(input, output, session) {

  cat("[Server] Start. Verbindung zur Datenbank...\n")
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

  checkCooldown <- function() {
    jetzt <- as.numeric(Sys.time())
    diff <- jetzt - LAST_DOWNLOAD_TIME
    if(diff < COOLDOWN_SECONDS) {
      stop(
        paste0("Warte bitte noch ", round(COOLDOWN_SECONDS - diff),
               " Sekunden, bevor erneut exportiert wird.")
      )
    }
    assign("LAST_DOWNLOAD_TIME", jetzt, envir = .GlobalEnv)
  }

  output$download_links <- downloadHandler(
    filename = function() {
      paste0("links_", Sys.Date(), ".csv")
    },
    content = function(file) {
      checkCooldown()
      df <- lade_links(con)
      write.csv(df, file, row.names=FALSE, fileEncoding='UTF-8')
    }
  )

  output$download_metadata <- downloadHandler(
    filename = function() {
      paste0("media_metadata_", Sys.Date(), '.csv')
    },
    content = function(file) {
      checkCooldown()
      df <- lade_media_metadata(con)
      write.csv(df, file, row.names=FALSE, fileEncoding='UTF-8')
    }
  )

  output$download_timeseries <- downloadHandler(
    filename = function() {
      paste0("media_time_series_", Sys.Date(), '.csv')
    },
    content = function(file) {
      checkCooldown()
      df <- lade_media_time_series(con)
      write.csv(df, file, row.names=FALSE, fileEncoding='UTF-8')
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
