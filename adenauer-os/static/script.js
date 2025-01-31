// =========================================================================================
//   script.js
// =========================================================================================

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

/*
  NUR AN DIESER STELLE ANGEPASST:
  Größere und fette Darstellung des Session-Namens in derselben Zeile
  wie das Bild. Zusätzlich wird der Name aus /session_name geladen und
  eingesetzt.
*/
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
    <!-- Platzhalter, wird nachträglich per fetch('/benutzer_info') gefüllt -->
    <div id="userDetails" style="font-size:0.8rem; color:#666;">
      ...User-Agent wird geladen...
    </div>
  </div>
</div>
`;

// Fenster #1
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
      <li><a href="#" class="entry-link" data-target="window15">leere Datei</a></li>
      <li><a href="#" class="entry-link" data-target="window17">Anweisungen zu Telearbeit</a></li>
    </ul>
  </div>
</div>
`;

// #3: Hilfe
const template3 = `
<div class="window modal-window" data-win="win3" style="width:800px; height:550px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Hilfe</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <!-- Iframe zeigt auf /hilfe_extended -->
    <iframe src="/hilfe_extended" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;


// #4: Programmquelle
const template4 = `
<div class="window modal-window" data-win="win4" style="width:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h2 class="title">Programmquelle </h2>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <h2>Adenauer OS <br> Projekt Tricktok</h2>
    <p>Adenauer OS ist ein Mehrbenutzer-Betriebssystem, dafür entwicklet, rechtsextreme Inhalte auf TikTok zu identifizieren. </p>
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
    <h1 class="title">Tricktok-Suche</h1>
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
<div class="window modal-window" data-win="win15" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">leere Datei</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="padding:1rem;">
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
      Für die parallele Nutzung der TikTok-App auf einem mobilen Endgerät erweist sich dieses Verfahren als besonders zweckmäßig. 
      Sollte bei der Sichtung verdächtiger Inhalte ein erhöhtes Gefährdungspotential erkannt werden, wird ausdrücklich angeordnet, den entsprechenden Kanal umgehend und unter Nutzung der zentralen Fahndungsliste zu melden.
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
<div class="window modal-window" data-win="win13" style="width:1000px; height:700px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Player</h1>
    <span class="close"></span>
  </div>
  <p>Video-Bereich außer Betrieb<br><br> Ein Systemadministrator wurde informiert.</p>
</div>
`;

const template19 = `
<div class="window modal-window" data-win="win19" style="width:800px; height:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Nachrichten</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://neuters.de/search?query=tiktok" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

const template20 = `
<div class="window modal-window" data-win="win20" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Kontakt</h1>
    <span class="close"></span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Kontaktaufnahme über: [Kontaktmöglichkeiten]</p>
  </div>
</div>
`;

/***********************************************
 * createWindow()
 ***********************************************/
function createWindow(template, windowKey) {
  if (openedWindows[windowKey]) {
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
    modalEl.style.left = "60px";
    modalEl.style.top = "160px";
  }

  modalEl.addEventListener('mousedown', () => {
    zIndexCounter++;
    modalEl.style.zIndex = zIndexCounter;
    saveWindowPosition(modalEl, windowKey);
  });

  const closeBtn = modalEl.querySelector('.close');
  if (closeBtn) {
    closeBtn.addEventListener('click', () => {
      modalContainer.removeChild(modalEl);
      openedWindows[windowKey] = false;
      delete windowState[windowKey];
      saveWindowState();
    });
  }

  makeDraggable(modalEl, windowKey);

  // Fenster #1: Einträge öffnen
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

  // Beim Öffnen von Fenster #2 => User-Agent und Random-Name nachladen
  if (windowKey === 'window2') {
    // User-Agent
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

    // Random Name aus der Session
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
    case 'window12': return template12;
    case 'window13': return template13;
    case 'window19': return template19;
    case 'window20': return template20;
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
  for (const key in windowState) {
    if (windowState.hasOwnProperty(key)) {
      createWindow(getTemplate(key), key);
    }
  }
});

// Button-Handler
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

// Icons #6..#10
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

// Icon #12, #13
const icon12 = document.getElementById('icon12');
if (icon12) {
  icon12.addEventListener('click', () => {
    createWindow(getTemplate('window12'), 'window12');
  });
}
const icon13 = document.getElementById('icon13');
if (icon13) {
  icon13.addEventListener('click', () => {
    createWindow(getTemplate('window13'), 'window13');
  });
}

// Icon #14 => Fenster #19
const icon14 = document.getElementById('icon14');
if (icon14) {
  icon14.addEventListener('click', () => {
    createWindow(getTemplate('window19'), 'window19');
  });
}

// Button #20
const btn20 = document.getElementById('openWindow20');
if (btn20) {
  btn20.addEventListener('click', (e) => {
    e.preventDefault();
    createWindow(getTemplate('window20'), 'window20');
  });
}

// CSV-Export Link (optional)
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
