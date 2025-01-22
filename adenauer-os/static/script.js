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
    <h1 class="title">Verzeichnis (Fenster #1)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Liste von Einträgen:</p>
    <ul>
      <li><a href="#" class="entry-link" data-target="window14">Wortwolke (#14)</a></li>
      <li><a href="#" class="entry-link" data-target="window15">Eintrag B (#15)</a></li>
      <li><a href="#" class="entry-link" data-target="window16">Eintrag C (#16)</a></li>
      <li><a href="#" class="entry-link" data-target="window17">Eintrag D (#17)</a></li>
    </ul>
  </div>
</div>
`;

// #2: Benutzeraccount
const template2 = `
<div class="window modal-window" data-win="win2" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Benutzerinfo (Fenster #2)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Infos zum angemeldeten Benutzer (Platzhalter).</p>
  </div>
</div>
`;

// #3: Hilfe
const template3 = `
<div class="window modal-window" data-win="win3" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Hilfe (Fenster #3)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
  <h3>Hilfeseite</h3>
    <p>Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed eiusmod tempor incidunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquid ex ea commodi consequat. Quis aute iure reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint obcaecat cupiditat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.</p>
  </div>
</div>
`;

// #4: Programmquelle
const template4 = `
<div class="window modal-window" data-win="win4" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Programmquelle (Fenster #4)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Quellcode-Info oder Hinweise.</p>
  </div>
</div>
`;

// #8: Fahndungsliste (Iframe)
const template8 = `
<div class="window modal-window" data-win="win8" style="width:800px; height:600px;">
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
<div class="window modal-window" data-win="win9" style="width:800px; height:600px;">
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
    <h1 class="title">Notiz (Fenster #10)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Leeres Fenster für Notizen (Platzhalter).</p>
  </div>
</div>
`;

// #14..#17: Unterfenster vom Verzeichnis #1
const template14 = `
<div class="window modal-window" data-win="win14" style="width:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Wortwolke (Fenster #14)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="text-align:center;">
    <img src="/static/wolke.png" alt="Wolke" style="max-width:100%; height:auto;">
  </div>
</div>
`;
const template15 = `
<div class="window modal-window" data-win="win15" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Eintrag B (Fenster #15)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Detail zu Eintrag B.</p>
  </div>
</div>
`;
const template16 = `
<div class="window modal-window" data-win="win16" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Eintrag C (Fenster #16)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Detail zu Eintrag C.</p>
  </div>
</div>
`;
const template17 = `
<div class="window modal-window" data-win="win17" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Eintrag D (Fenster #17)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Detail zu Eintrag D.</p>
  </div>
</div>
`;

/***********************************************
 * createWindow()
 ***********************************************/
function createWindow(template, windowKey) {
  if (openedWindows[windowKey]) {
    return; // Fenster bereits offen
  }
  openedWindows[windowKey] = true;

  const wrapper = document.createElement('div');
  wrapper.innerHTML = template.trim();
  const modalEl = wrapper.firstElementChild;

  // Z-Index hochsetzen
  zIndexCounter++;
  modalEl.style.zIndex = zIndexCounter;

  // Position aus localStorage?
  if (windowState[windowKey]) {
    const { left, top, zIndex } = windowState[windowKey];
    if (typeof left === 'number') modalEl.style.left = left + 'px';
    if (typeof top === 'number') modalEl.style.top = top + 'px';
    if (typeof zIndex === 'number') {
      modalEl.style.zIndex = zIndex;
      zIndexCounter = Math.max(zIndexCounter, zIndex);
    }
  } else {
    // Standard-Position
    modalEl.style.left = "60px";
    modalEl.style.top = "60px";
  }

  // Klick aufs Fenster => in den Vordergrund
  modalEl.addEventListener('mousedown', () => {
    zIndexCounter++;
    modalEl.style.zIndex = zIndexCounter;
    saveWindowPosition(modalEl, windowKey);
  });

  // Schließen
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

  // Spezieller Fall: Verzeichnis (#1) => Links, die Unterfenster öffnen
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

  // Maus
  titleBar.addEventListener('mousedown', onMouseDown);
  // Touch
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
    case 'window1':  return template1;  // Index/Verzeichnis
    case 'window2':  return template2;  // Benutzerinfo
    case 'window3':  return template3;  // Hilfe
    case 'window4':  return template4;  // Programmquelle
    case 'window8':  return template8;  // Fahndungsliste
    case 'window9':  return template9;  // Suche
    case 'window10': return template10; // Notiz
    case 'window14': return template14; // Wortwolke
    case 'window15': return template15;
    case 'window16': return template16;
    case 'window17': return template17;
    default:
      return template4; // Fallback => "Programmquelle"
  }
}

/***********************************************
 * Init
 ***********************************************/
const modalContainer = document.getElementById('modalContainer');

document.addEventListener('DOMContentLoaded', () => {
  loadWindowState();
  // Bereits geöffnete Fenster aus localStorage wiederherstellen
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

// Beispiel: Export-Link Cooldown
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
