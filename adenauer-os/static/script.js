/***********************************************
 * Globale Variablen
 ***********************************************/
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
  window20: false
};

let windowState = {};

/***********************************************
 * TEMPLATES
 ***********************************************/
// #1: Verzeichnis (Index)
const template1 = `
<div class="window modal-window" data-win="win1" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Index</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Liste von Einträgen:</p>
    <ul>
      <li><a href="#" class="entry-link" data-target="window14">Hashtag - Wortwolke </a></li>
	  <li><a href="#" class="entry-link" data-target="window16">Logo</a></li>
      <li><a href="#" class="entry-link" data-target="window15">Eintrag B (#15)</a></li>
      <li><a href="#" class="entry-link" data-target="window17">Anweisungen zu Telearbeit</a></li>
    </ul>
  </div>
</div>
`;

// #2: Benutzeraccount
const template2 = `
<div class="window modal-window" data-win="win2" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Benutzerkonto</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
  <img src="/static/icon7.png" alt="icon7" width="64" height="64">
    <p>Infos zum angemeldeten Benutzer (Platzhalter).</p>
  </div>
</div>
`;

// #3: Hilfe
const template3 = `
<div class="window modal-window" data-win="win3" style="width:800px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Hilfe</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>
      Offizielle Dienstanweisung zur Verwendung von AdenauerOS .  Folgende Teilfunktionen sind vorgesehen:<br><br>

      <img src="/static/icon6.png" alt="icon6" width="64" height="64"><br>
      <strong>Index</strong><br>
      Verzeichnisstruktur für unterschiedlichste Dateien zum laufenden Vorhaben. Umfasst archivierte Vorgänge zuständiger Dienststellen.<br><br>

      <img src="/static/icon8.png" alt="icon8" width="64" height="64"><br>
      <strong>Fahndungsliste</strong><br>
      Wachsende Sammlung potenziell verfassungsfeindlicher TikTok-Kanäle. Zentrale Datenbank mit Lese- und Schreibzugriff im gesamten Bundesgebiet. Ziel besteht in der Dokumentation sämtlicher relevanter Inhalte von der Unterhaltungsplatform Tiktok.<br><br>
      Ein spezieller Zugriff für die Ermittlungen in Telearbeit ist im Index unter: <strong>"Anweisungen zu Telearbeit"</strong> hinterlegt.
      <br><br>

      <img src="/static/icon9.png" alt="icon9" width="64" height="64"><br>
      <strong>Suche</strong><br>
      Umfassende Durchsuchungs- und Filterfunktionen für alle observierten Videotitel. Konfigurierbare Verteilung häufig verwendeter Wörter per Wortwolke erleichtern die Observierung der Kanäle.
    </p>
  </div>
</div>
`;

// #4: Programmquelle
const template4 = `
<div class="window modal-window" data-win="win4" style="width:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h2 class="title">Programmquelle </h2>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <h2>Adenauer OS - Projekt Tricktok</h2>
    <p>Dieses Programm ist ein Betriebssystem, dafür entwicklet, rechtsradikale Inhalte auf TikTok zu identifizieren. </p>
    <p>Version: v.02 | Buildnummer: 1933.1</p>
    <img src="/static/qrcodegithub.png" alt="github" style="transform: scale(1); width:auto; height:auto; max-width:none; max-height:none;">
  </div>
</div>
`;

// #8: Fahndungsliste (Iframe)
const template8 = `
<div class="window modal-window" data-win="win8" style="width:800px; height:680px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Fahndungsliste</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="/fahndungsliste_db" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

// #9: Suche (Iframe)
const template9 = `
<div class="window modal-window" data-win="win9" style="width:1000px; height:700px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Tricktok-Suche</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://tricktok.afd-verbot.de/suche" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;


// #10: Notiz
const template10 = `
<div class="window modal-window" data-win="win10" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Notiz 10</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>(Platzhalter).</p>
  </div>
</div>
`;

const template14 = `
<div class="window modal-window" data-win="win14" style="width:1000px; height:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Hashtag - Wortwolke</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="text-align:center; display:flex; justify-content:center; align-items:center; width:100%; height:calc(100% - 40px); padding:10px;">
    <img src="/static/wolke.png" alt="Wolke" style="transform: scale(0.16); width:auto; height:auto; max-width:none; max-height:none;">
  </div>
</div>
`;

const template15 = `
<div class="window modal-window" data-win="win15" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Eintrag B (#15)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Detail zu Eintrag B.</p>
  </div>
</div>
`;

const template16 = `
<div class="window modal-window" data-win="win16" style="width:auto; max-width:850px; margin:auto; background-color:#fff;">
  <div class="title-bar" style="display:flex; justify-content:space-between; align-items:center; padding:10px;">
    <h1 class="title" style="margin:0;">Logo</h1>
    <span class="close" style="cursor:pointer;">[x]</span>
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
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <h2>Anweisungen zu Telearbeit</h2>
    <p>
      Die Ausübung dienstlicher Tätigkeiten im Rahmen der Telearbeit, sei es von der häuslichen Arbeitsstätte oder einem anderen entfernten Standort aus, ist ausschließlich unter Zuhilfenahme der hierfür vorgesehenen Plattform durchzuführen.
    </p>
    <p>
      Für die parallele Nutzung der TikTok-App auf einem mobilen Endgerät erweist sich diese Seite als besonders zweckmäßig. 
      Sollte bei der Sichtung verdächtiger Inhalte ein erhöhtes Gefährdungspotential erkannt werden, wird ausdrücklich angeordnet, den entsprechenden Kanal umgehend und unter Nutzung der zentralen Fahndungsliste zu melden.
    </p>
<center>
    <img src="/static/qrcodefahndung.png" alt="QR-Code Fahndungsliste" style="transform: scale(1); width:auto; height:auto; max-width:none; max-height:none;">
</center>
 </div>
</div>
`;


/***********************************************
 * createWindow()
 ***********************************************/
function createWindow(template, windowKey) {
  // Keine Dopplung, falls bereits geöffnet:
  if (openedWindows[windowKey]) {
    return;
  }
  openedWindows[windowKey] = true;

  // Template in DOM-Element umwandeln:
  const wrapper = document.createElement('div');
  wrapper.innerHTML = template.trim();
  const modalEl = wrapper.firstElementChild;

  // Z-Index erhöhen
  zIndexCounter++;
  modalEl.style.zIndex = zIndexCounter;

  // Position via localStorage laden, sonst Default:
  if (windowState[windowKey]) {
    const { left, top, zIndex } = windowState[windowKey];
    if (typeof left === 'number') modalEl.style.left = left + 'px';
    if (typeof top === 'number') modalEl.style.top = top + 'px';
    if (typeof zIndex === 'number') {
      modalEl.style.zIndex = zIndex;
      zIndexCounter = Math.max(zIndexCounter, zIndex);
    }
  } else {
    modalEl.style.left = "60px";
    modalEl.style.top = "160px";
  }

  // Klick => Fensterebene nach oben (zIndex)
  modalEl.addEventListener('mousedown', () => {
    zIndexCounter++;
    modalEl.style.zIndex = zIndexCounter;
    saveWindowPosition(modalEl, windowKey);
  });

  // Close-Button
  const closeBtn = modalEl.querySelector('.close');
  if (closeBtn) {
    closeBtn.addEventListener('click', () => {
      modalContainer.removeChild(modalEl);
      openedWindows[windowKey] = false;
      delete windowState[windowKey];
      saveWindowState();
    });
  }

  // Draggable
  makeDraggable(modalEl, windowKey);

  // Bei Fenster #1 => Interne Links
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

  // An DOM anhängen
  modalContainer.appendChild(modalEl);
}

/***********************************************
 * Draggable
 ***********************************************/
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
    zIndexCounter++;
    windowEl.style.zIndex = zIndexCounter;

    const rect = windowEl.getBoundingClientRect();
    offsetX = e.clientX - rect.left;
    offsetY = e.clientY - rect.top;

    document.addEventListener('mousemove', onMouseMove);
    document.addEventListener('mouseup', onMouseUp);
  }

  function onMouseMove(e) {
    if (!isDragging) return;
    let newLeft = e.clientX - offsetX;
    let newTop = e.clientY - offsetY;
    newLeft = Math.round(newLeft / gridSize) * gridSize;
    newTop = Math.round(newTop / gridSize) * gridSize;
    if (newLeft < 0) newLeft = 0;
    if (newTop < 0) newTop = 0;
    windowEl.style.left = newLeft + 'px';
    windowEl.style.top = newTop + 'px';
  }

  function onMouseUp() {
    isDragging = false;
    document.removeEventListener('mousemove', onMouseMove);
    document.removeEventListener('mouseup', onMouseUp);
    saveWindowPosition(windowEl, windowKey);
  }

  // Touch
  function onTouchStart(e) {
    e.preventDefault();
    isDragging = true;
    zIndexCounter++;
    windowEl.style.zIndex = zIndexCounter;

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
    let newTop = touch.clientY - offsetY;
    newLeft = Math.round(newLeft / gridSize) * gridSize;
    newTop = Math.round(newTop / gridSize) * gridSize;
    if (newLeft < 0) newLeft = 0;
    if (newTop < 0) newTop = 0;
    windowEl.style.left = newLeft + 'px';
    windowEl.style.top = newTop + 'px';
  }

  function onTouchEnd() {
    isDragging = false;
    document.removeEventListener('touchmove', onTouchMove);
    document.removeEventListener('touchend', onTouchEnd);
    saveWindowPosition(windowEl, windowKey);
  }
}

/***********************************************
 * localStorage
 ***********************************************/
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

/***********************************************
 * getTemplate(key)
 ***********************************************/
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
    default:
      return template4; // Fallback
  }
}

/***********************************************
 * Init
 ***********************************************/
const modalContainer = document.getElementById('modalContainer');

document.addEventListener('DOMContentLoaded', () => {
  loadWindowState();
  // Bereits geöffnete Fenster aus localStorage erneut öffnen:
  for (const key in windowState) {
    if (windowState.hasOwnProperty(key)) {
      createWindow(getTemplate(key), key);
    }
  }
});

// Menü => Hilfe(#3), Programmquelle(#4)
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

// Desktop-Icons
const icon6 = document.getElementById('icon6');
if (icon6) {
  icon6.addEventListener('click', () => {
    createWindow(getTemplate('window1'), 'window1');
  });
}
const icon7 = document.getElementById('icon7');
if (icon7) {
  icon7.addEventListener('click', () => {
    createWindow(getTemplate('window2'), 'window2');
  });
}
const icon8 = document.getElementById('icon8');
if (icon8) {
  icon8.addEventListener('click', () => {
    createWindow(getTemplate('window8'), 'window8');
  });
}
const icon9 = document.getElementById('icon9');
if (icon9) {
  icon9.addEventListener('click', () => {
    createWindow(getTemplate('window9'), 'window9');
  });
}
const icon10 = document.getElementById('icon10');
if (icon10) {
  icon10.addEventListener('click', () => {
    createWindow(getTemplate('window10'), 'window10');
  });
}

// Beispiel: Cooldown für Export-Link (optional)
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
