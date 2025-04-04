// script.js

let zIndexCounter = 100;

const openedWindows = {
  window1: false,
  window2: false,
  window3: false,
  window4: false,
  window5: false,
  window6: false,
  window7: false,
  window8: false,
  window9: false,
  window10: false,
  window11: false,
  window12: false,
  window13: false,
  window14: false,
  window15: false,
  window16: false,
  window17: false,
  window18: false,
  window19: false,
  window20: false,
  window21: false,
  window22: false,
  window23: false,
  window24: false,
  window25: false,
  window26: false,
  window27: false,
  window28: false
};

let windowState = {};
let openCount = 0;

// Zoom-Faktor
let currentZoomLevel = 1.0;

// Hilfsfunktionen zum Deaktivieren / Aktivieren von pointer-events bei iframes
function setIframesPointerEvents(windowEl, enabled) {
  const iframes = windowEl.querySelectorAll("iframe");
  iframes.forEach(iframe => {
    iframe.style.pointerEvents = enabled ? "auto" : "none";
  });
}

function bringWindowToFront(activeWindow) {
  zIndexCounter++;
  activeWindow.style.zIndex = zIndexCounter;
  const allWindows = document.querySelectorAll(".modal-window");
  allWindows.forEach(win => {
    if (win === activeWindow) {
      win.style.pointerEvents = "auto";
    } else {
      win.style.pointerEvents = "none";
    }
  });
}

function restoreAllWindowsPointerEvents() {
  const allWindows = document.querySelectorAll(".modal-window");
  allWindows.forEach(win => {
    win.style.pointerEvents = "auto";
  });
}

// ------------------------------------------------------------
// Vorhandene Templates
// ------------------------------------------------------------
const template2 = `
<div class="window modal-window" data-win="win2" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Benutzerkonto</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="padding:1rem; font-size:14px;">
    <div style="display:flex; align-items:center;">
      <img src="/static/icon7.png" alt="icon7" width="64" height="64">
      <span id="sessionName" style="font-size:1.2rem; font-weight:bold; margin-left:10px;">
        ...Lade Zufallsnamen...
      </span>
    </div>
    <p>Infos zum angemeldeten Benutzer:</p>
    <div id="userDetails" style="font-size:0.8rem; color:#666;">
      ...User-Agent wird geladen...
    </div>
  </div>
</div>
`;

const template1 = `
<div class="window modal-window" data-win="win1" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Index</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Verzeichnis</p>
    <ul>
      <li><a href="#" class="entry-link" data-target="window14">Hashtag - Wortwolke</a></li>
      <li><a href="#" class="entry-link" data-target="window16">Logo</a></li>
      <li><a href="#" class="entry-link" data-target="window17">Anweisungen zu Telearbeit</a></li>
    </ul>
  </div>
</div>
`;

const template21 = `
<div class="window modal-window" data-win="win3" style="width:600px; height:350px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Kleiner Max</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe title="Max Krah #AfD über die Probleme und Werte junger #Männer"
            width="560"
            height="315"
            src="https://archive.afd-verbot.de/videos/embed/b666e9c0-d5ae-4817-b120-3ae0fe949576?start=16s"
            frameborder="0"
            allowfullscreen=""
            sandbox="allow-same-origin allow-scripts allow-popups allow-forms">
    </iframe>
  </div>
</div>
`;

const template3 = `
<div class="window modal-window" data-win="win3" style="width:800px; height:550px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Hilfe</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="/hilfe_extended" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template4 = `
<div class="window modal-window" data-win="win4" style="width:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h2 class="title">Programmquelle </h2>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <h2>Adenauer OS <br> Projekt Tricktok</h2>
    <p>Adenauer OS ist ein Mehrbenutzer-Betriebssystem, entwickelt zur Untersuchung rechtsextremer Inhalte auf TikTok.</p>
    <p>Version: v.02 | Buildnummer: 1933.1</p>
    <img src="/static/qrcodegithub.png" alt="github" style="transform: scale(1); width:auto; height:auto; max-width:none; max-height:none;">
  </div>
</div>
`;

const template8 = `
<div class="window modal-window" data-win="win8" style="width:800px; height:680px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Fahndungsliste</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="/fahndungsliste_db" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template9 = `
<div class="window modal-window" data-win="win9" style="width:1000px; height:700px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Hashtag-Suche</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://tricktok.afd-verbot.de/suche" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template10 = `
<div class="window modal-window" data-win="win10" style="width:750px; height:auto;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Archiv</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="padding:1rem; height:auto;">
    <iframe 
      src="https://py.afd-verbot.de/tricktok-archiv/" 
      style="width:100%; min-height:600px; height:auto; border:none;">
    </iframe>
  </div>
</div>
`;

const template14 = `
<div class="window modal-window" data-win="win14" style="width:1000px; height:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Hashtag - Wortwolke</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="text-align:center; display:flex; justify-content:center; align-items:center; width:100%; height:calc(100% - 40px); padding:10px;">
    <img src="/static/wolke.png" alt="Wolke" style="transform: scale(0.16); width:auto; height:auto; max-width:none; max-height:none;">
  </div>
</div>
`;

const template15 = `
<div class="window modal-window" data-win="win15" style="width:800px; height:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Anweisung zu Datenfilterung</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="/metadatenfilter" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template16 = `
<div class="window modal-window" data-win="win16" style="width:auto; max-width:850px; margin:auto; background-color:#fff;">
  <div class="title-bar" style="display:flex; justify-content:space-between; align-items:center; padding:10px;">
    <h1 class="title" style="margin:0;">Logo</h1>
    <span class="close" style="cursor:pointer;"></span>
  </div>
  <div class="window-pane" style="text-align:center; display:flex; justify-content:center; align-items:center; width:100%; padding:1px;">
    <img src="/static/banderole2.png" alt="logo" style="width:auto; height:auto; max-width:100%; max-height:calc(100vh - 100px);">
  </div>
</div>
`;

const template17 = `
<div class="window modal-window" data-win="win17" style="width:800px; height:800px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Anweisungen zu Telearbeit</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <h2>Anweisungen zu Telearbeit</h2>
    <p>
      Die Ausübung dienstlicher Tätigkeiten im Rahmen der Telearbeit, sei es von der häuslichen Arbeitsstätte oder einem anderen entfernten Standort aus, ist ausschließlich unter Zuhilfenahme der hierfür vorgesehenen Plattform durchzuführen.
    </p>
    <p>
      Für die parallele Nutzung der TikTok-App auf einem mobilen Endgerät erweist sich dieses Verfahren als zweckmäßig.
      Sollte bei der Sichtung verdächtiger Inhalte ein erhöhtes Gefährdungspotential erkannt werden, wird angeordnet, den entsprechenden Kanal umgehend und unter Nutzung der zentralen Fahndungsliste zu melden.
    </p>
    <center>
      <img src="/static/qrcodefahndung.png" alt="QR-Code Fahndungsliste" style="transform: scale(1); width:auto; height:auto; max-width:none; max-height:none;">
    </center>
  </div>
</div>
`;

const template12 = `
<div class="window modal-window" data-win="win12" style="width:1200px; height:700px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Statistiktok</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://py.afd-verbot.de/statistiktok" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template13 = `
<div class="window modal-window" data-win="win13" style="width:750px; height:700px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Tricktok-Live</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://tricktok.net" style="width:155%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template19 = `
<div class="window modal-window" data-win="win19" style="max-width:100vw; max-height:70vh; width:40%; height:100%;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Jukebox</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://py.afd-verbot.de/jukebox/" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template20 = `
<div class="window modal-window" data-win="win20" style="width:800px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Kontakt</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <center>
      <br><br>
      <p>
        adenauer@tutamail.com<br>
        der-adenauer.de
      </p>
    </center>
  </div>
</div>
`;

const template22 = `
<div class="window modal-window" data-win="win22" style="width:800px; height:650px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Bilder-Archiv</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="display:flex; justify-content:center; align-items:center; width:100%; height:calc(100% - 2rem); padding:1rem;">
    <iframe src="https://py.afd-verbot.de/tiktok/" style="width:100%; height:80%; border:none; display:block; object-fit: contain;"></iframe>
  </div>
</div>
`;

const template23 = `
<div class="window modal-window" data-win="win23" style="width:1000px; height:700px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Tricktok-Photo</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:1rem;">
    <iframe src="https://py.afd-verbot.de/photoarchiv/" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template24 = `
<div class="window modal-window" data-win="win24" style="width:1000px; height:700px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Zeitreihen</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:1rem;">
    <iframe src="https://py.afd-verbot.de/zeitreihen/?uploader=23.02.25afd&video=7471398852642278678" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template18 = `
<div class="window modal-window" data-win="win18" style="width:1000px; height:700px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Beweisführung</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:1rem;">
    <iframe src="https://py.afd-verbot.de/beweise" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template25 = `
<div class="window modal-window" data-win="win25" style="width:1000px; height:700px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Contentschleuder</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:1rem;">
    <iframe src="https://py.afd-verbot.de/bilderwerfer" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

/* Neue Fenster: Info (window26), Log (window27), Tricktok Maps (window28) */
const template26 = `
<div class="window modal-window" data-win="win26" style="width:800px; height:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Info</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://py.afd-verbot.de/intro/" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template27 = `
<div class="window modal-window" data-win="win27" style="width:600px; height:500px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Log</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://tricktok.afd-verbot.de/livelog/" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template28 = `
<div class="window modal-window" data-win="win28" style="width:800px; height:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Tricktok Maps</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://tiktok-code-of-practice-on-disinformation.shinyapps.io/europa/" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

// ------------------------------------------------------------
// Funktion zum Erzeugen von Fenstern
// ------------------------------------------------------------
function createWindow(template, windowKey) {
  if (openedWindows[windowKey]) {
    const existingWin = document.querySelector(`.modal-window[data-win="${windowKey}"]`);
    if (existingWin) {
      zIndexCounter++;
      existingWin.style.zIndex = zIndexCounter;
      saveWindowPosition(existingWin, windowKey);
    }
    return;
  }

  openedWindows[windowKey] = true;
  const wrapper = document.createElement('div');
  wrapper.innerHTML = template.trim();
  const modalEl = wrapper.firstElementChild;

  zIndexCounter++;
  modalEl.style.zIndex = zIndexCounter;

  if (windowState[windowKey]) {
    const { left, top, zIndex } = windowState[windowKey];
    if (typeof left === 'number') modalEl.style.left = left + 'px';
    if (typeof top === 'number') modalEl.style.top = top + 'px';
    if (typeof zIndex === 'number') {
      modalEl.style.zIndex = zIndex;
      zIndexCounter = Math.max(zIndexCounter, zIndex);
    }
  } else {
    const baseLeft = 60 + openCount * 20;
    const baseTop = 160 + openCount * 20;
    modalEl.style.left = baseLeft + "px";
    modalEl.style.top = baseTop + "px";
    openCount++;
  }

  modalEl.addEventListener('mousedown', () => {
    zIndexCounter++;
    modalEl.style.zIndex = zIndexCounter;
    saveWindowPosition(modalEl, windowKey);
  });

  const closeBtn = modalEl.querySelector('.close');
  if (closeBtn) {
    const handleClose = (evt) => {
      evt.preventDefault();
      modalContainer.removeChild(modalEl);
      openedWindows[windowKey] = false;
      delete windowState[windowKey];
      saveWindowState();
    };
    closeBtn.addEventListener('click', handleClose);
    closeBtn.addEventListener('touchend', handleClose, { passive: false });
  }

  makeDraggable(modalEl, windowKey);

  if (windowKey === 'window1') {
    const entryLinks = modalEl.querySelectorAll('.entry-link');
    entryLinks.forEach(link => {
      link.addEventListener('click', (e) => {
        e.preventDefault();
        const targetWin = link.getAttribute('data-target');
        createWindow(getTemplate(targetWin), targetWin);
      });
    });
  }

  if (windowKey === 'window2') {
    fetch('/benutzer_info')
      .then(response => response.text())
      .then(htmlSnippet => {
        const userDiv = modalEl.querySelector('#userDetails');
        if (userDiv) {
          userDiv.innerHTML = htmlSnippet;
        }
      })
      .catch(err => {
        console.error("Fehler beim Laden von /benutzer_info:", err);
      });

    fetch('/session_name')
      .then(response => response.text())
      .then(zufallsName => {
        const nameSpan = modalEl.querySelector('#sessionName');
        if (nameSpan) {
          nameSpan.textContent = zufallsName;
        }
      })
      .catch(err => {
        console.error("Fehler beim Laden von /session_name:", err);
      });
  }

  modalContainer.appendChild(modalEl);
}

// ------------------------------------------------------------
// Drag & Drop
// ------------------------------------------------------------
function makeDraggable(windowEl, windowKey) {
  const titleBar = windowEl.querySelector('.title-bar');
  const gridSize = 10;
  let offsetX = 0, offsetY = 0;
  let isDragging = false;

  titleBar.addEventListener('mousedown', onMouseDown);
  titleBar.addEventListener('touchstart', onTouchStart, { passive: false });

  function onMouseDown(e) {
    e.preventDefault();
    isDragging = true;
    document.body.style.userSelect = 'none';
    bringWindowToFront(windowEl);
    setIframesPointerEvents(windowEl, false);

    const rect = windowEl.getBoundingClientRect();
    offsetX = e.clientX - rect.left;
    offsetY = e.clientY - rect.top;

    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
  }

  function onMouseMove(e) {
    if (!isDragging) return;
    let newLeft = e.clientX - offsetX;
    let newTop  = e.clientY - offsetY;
    if (newLeft < 0) newLeft = 0;
    if (newTop < 0) newTop = 0;

    windowEl.style.left = newLeft + 'px';
    windowEl.style.top  = newTop + 'px';
  }

  function onMouseUp() {
    isDragging = false;
    restoreAllWindowsPointerEvents();
    setIframesPointerEvents(windowEl, true);
    document.body.style.userSelect = '';

    const leftRaw = parseFloat(windowEl.style.left) || 0;
    const topRaw  = parseFloat(windowEl.style.top)  || 0;
    const snappedLeft = Math.round(leftRaw / gridSize) * gridSize;
    const snappedTop  = Math.round(topRaw / gridSize) * gridSize;
    windowEl.style.left = snappedLeft + 'px';
    windowEl.style.top  = snappedTop + 'px';

    document.removeEventListener('mousemove', onMouseMove);
    document.removeEventListener('mouseup', onMouseUp);
    saveWindowPosition(windowEl, windowKey);
  }

  function onTouchStart(e) {
    e.preventDefault();
    isDragging = true;
    document.body.style.userSelect = 'none';
    bringWindowToFront(windowEl);
    setIframesPointerEvents(windowEl, false);

    const rect = windowEl.getBoundingClientRect();
    const touch = e.touches[0];
    offsetX = touch.clientX - rect.left;
    offsetY = touch.clientY - rect.top;

    document.addEventListener('touchmove', onTouchMove, { passive: false });
    document.addEventListener('touchend', onTouchEnd);
  }

  function onTouchMove(e) {
    if (!isDragging) return;
    e.preventDefault();
    const touch = e.touches[0];
    let newLeft = touch.clientX - offsetX;
    let newTop  = touch.clientY - offsetY;
    if (newLeft < 0) newLeft = 0;
    if (newTop < 0) newTop = 0;

    windowEl.style.left = newLeft + 'px';
    windowEl.style.top  = newTop + 'px';
  }

  function onTouchEnd() {
    isDragging = false;
    restoreAllWindowsPointerEvents();
    setIframesPointerEvents(windowEl, true);
    document.body.style.userSelect = '';

    const leftRaw = parseFloat(windowEl.style.left) || 0;
    const topRaw  = parseFloat(windowEl.style.top)  || 0;
    const snappedLeft = Math.round(leftRaw / gridSize) * gridSize;
    const snappedTop  = Math.round(topRaw / gridSize) * gridSize;
    windowEl.style.left = snappedLeft + 'px';
    windowEl.style.top  = snappedTop + 'px';

    document.removeEventListener('touchmove', onTouchMove);
    document.removeEventListener('touchend', onTouchEnd);
    saveWindowPosition(windowEl, windowKey);
  }
}

function saveWindowPosition(modalEl, windowKey) {
  const left = parseInt(modalEl.style.left, 10) || 0;
  const top = parseInt(modalEl.style.top, 10) || 0;
  const zIndex = parseInt(modalEl.style.zIndex, 10) || 100;
  windowState[windowKey] = { left, top, zIndex };
  saveWindowState();
}

function saveWindowState() {
  localStorage.setItem('tiktokDesktopState', JSON.stringify(windowState));
}

function loadWindowState() {
  const data = localStorage.getItem('tiktokDesktopState');
  if (data) {
    windowState = JSON.parse(data);
  }
}

// ------------------------------------------------------------
// Zuordnung der Templates zu Window-Keys
// ------------------------------------------------------------
function getTemplate(key) {
  switch (key) {
    case 'window1':  return template1;
    case 'window2':  return template2;
    case 'window3':  return template3;
    case 'window4':  return template4;
    case 'window8':  return template8;
    case 'window9':  return template9;
    case 'window10': return template10;
    case 'window14': return template14;
    case 'window15': return template15;
    case 'window16': return template16;
    case 'window17': return template17;
    case 'window12': return template12;
    case 'window13': return template13;
    case 'window19': return template19;
    case 'window20': return template20;
    case 'window22': return template22;
    case 'window23': return template23;
    case 'window24': return template24;
    case 'window18': return template18;
    case 'window25': return template25;
    case 'window26': return template26;
    case 'window27': return template27;
    case 'window28': return template28;
    default:
      return template4; 
  }
}

// ------------------------------------------------------------
// Initialisierung
// ------------------------------------------------------------
const modalContainer = document.getElementById('modalContainer');

document.addEventListener('DOMContentLoaded', () => {
  loadWindowState();
  for (const key in windowState) {
    if (windowState.hasOwnProperty(key)) {
      createWindow(getTemplate(key), key);
    }
  }
});

// Zoom-Funktionen
function setZoom(level) {
  document.body.style.zoom = level;
  currentZoomLevel = level;
}

const zoomInBtn = document.getElementById('zoomIn');
const zoomOutBtn = document.getElementById('zoomOut');
const zoomResetBtn = document.getElementById('zoomReset');

if (zoomInBtn) {
  zoomInBtn.addEventListener('click', (e) => {
    e.preventDefault();
    const newZoom = currentZoomLevel + 0.1;
    setZoom(newZoom);
  });
}
if (zoomOutBtn) {
  zoomOutBtn.addEventListener('click', (e) => {
    e.preventDefault();
    const newZoom = currentZoomLevel - 0.1;
    if (newZoom > 0) {
      setZoom(newZoom);
    }
  });
}
if (zoomResetBtn) {
  zoomResetBtn.addEventListener('click', (e) => {
    e.preventDefault();
    setZoom(1.0);
  });
}

const btn3 = document.getElementById('openWindow3');
if (btn3) {
  btn3.addEventListener('click', (e) => {
    e.preventDefault();
    createWindow(getTemplate('window3'), 'window3');
  });
}
const btn4 = document.getElementById('openWindow4');
if (btn4) {
  btn4.addEventListener('click', (e) => {
    e.preventDefault();
    createWindow(getTemplate('window4'), 'window4');
  });
}

const btn20 = document.getElementById('openWindow20');
if (btn20) {
  btn20.addEventListener('click', (e) => {
    e.preventDefault();
    createWindow(getTemplate('window20'), 'window20');
  });
}

// Icon-Klicks:
const icon6 = document.getElementById('icon6');   // Index
if (icon6) {
  icon6.addEventListener('click', () => {
    createWindow(getTemplate('window1'), 'window1');
  });
}
const icon7 = document.getElementById('icon7');   // Benutzer
if (icon7) {
  icon7.addEventListener('click', () => {
    createWindow(getTemplate('window2'), 'window2');
  });
}
const icon8 = document.getElementById('icon8');   // Fahndung
if (icon8) {
  icon8.addEventListener('click', () => {
    createWindow(getTemplate('window8'), 'window8');
  });
}
const icon18 = document.getElementById('icon18'); // Beweis-führung
if (icon18) {
  icon18.addEventListener('click', () => {
    createWindow(getTemplate('window18'), 'window18');
  });
}

const icon20 = document.getElementById('icon20'); // Info
if (icon20) {
  icon20.addEventListener('click', () => {
    createWindow(getTemplate('window26'), 'window26');
  });
}
const icon9 = document.getElementById('icon9');   // Hashtag-Suche
if (icon9) {
  icon9.addEventListener('click', () => {
    createWindow(getTemplate('window9'), 'window9');
  });
}
const icon12 = document.getElementById('icon12'); // Statistiktok
if (icon12) {
  icon12.addEventListener('click', () => {
    createWindow(getTemplate('window12'), 'window12');
  });
}
const icon17 = document.getElementById('icon17'); // Zeitreihen
if (icon17) {
  icon17.addEventListener('click', () => {
    createWindow(getTemplate('window24'), 'window24');
  });
}

const icon10 = document.getElementById('icon10'); // Video-Archiv
if (icon10) {
  icon10.addEventListener('click', () => {
    createWindow(getTemplate('window10'), 'window10');
  });
}
const icon13 = document.getElementById('icon13'); // Tricktok-Live
if (icon13) {
  icon13.addEventListener('click', () => {
    createWindow(getTemplate('window13'), 'window13');
  });
}
const icon15 = document.getElementById('icon15'); // Bilder-Archiv
if (icon15) {
  icon15.addEventListener('click', () => {
    createWindow(getTemplate('window22'), 'window22');
  });
}
const icon16 = document.getElementById('icon16'); // Tricktok-Photo
if (icon16) {
  icon16.addEventListener('click', () => {
    createWindow(getTemplate('window23'), 'window23');
  });
}

const icon14 = document.getElementById('icon14'); // Juke-Box
if (icon14) {
  icon14.addEventListener('click', () => {
    createWindow(getTemplate('window19'), 'window19');
  });
}

const icon19 = document.getElementById('icon19'); // Tricktok-Maps
if (icon19) {
  icon19.addEventListener('click', () => {
    createWindow(getTemplate('window28'), 'window28');
  });
}

const icon22 = document.getElementById('icon22'); // Content-Schleuder
if (icon22) {
  icon22.addEventListener('click', () => {
    createWindow(getTemplate('window25'), 'window25');
  });
}

const icon21 = document.getElementById('icon21'); // Log
if (icon21) {
  icon21.addEventListener('click', () => {
    createWindow(getTemplate('window27'), 'window27');
  });
}

const exportLink = document.getElementById('exportLink');
if (exportLink) {
  exportLink.addEventListener('click', () => {
    exportLink.style.pointerEvents = 'none';
    exportLink.style.opacity = '0.5';
    setTimeout(() => {
      exportLink.style.pointerEvents = 'auto';
      exportLink.style.opacity = '1';
    }, 30000);
  });
}
