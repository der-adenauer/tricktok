/***********************************************
 * Globals
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
 * Templates
 ***********************************************/
// #1: Verzeichnis
const template1 = `
<div class="window modal-window" data-win="win1" style="width:400px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Verzeichnis (Fenster #1)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="padding:1rem;">
    <p>Liste von Einträgen:</p>
    <ul>
      <li><a href="#" class="entry-link" data-target="window14">Wortwolke</a></li>
      <li><a href="#" class="entry-link" data-target="window15">Eintrag B => (#15)</a></li>
      <li><a href="#" class="entry-link" data-target="window16">Eintrag C => (#16)</a></li>
      <li><a href="#" class="entry-link" data-target="window17">Eintrag D => (#17)</a></li>
    </ul>
  </div>
</div>
`;

// #2: Benutzerinfo
const template2 = `
<div class="window modal-window" data-win="win2">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Benutzerinfo (Fenster #2)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Hier stehen Infos zum angemeldeten Benutzer.</p>
  </div>
</div>
`;

// #3: Programmquellen
const template3 = `
<div class="window modal-window" data-win="win3">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Programmquellen (Fenster #3)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Hier könnte man den Quellcode einblenden oder so.</p>
  </div>
</div>
`;

// #4: Einstellungen
const template4 = `
<div class="window modal-window" data-win="win4">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Einstellungen (Fenster #4)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Hier könnten Einstellungen sein.</p>
  </div>
</div>
`;

// #5: tt-tube -> Neu
const template5 = `
<div class="window modal-window" data-win="win5">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">tt-tube Neu (Fenster #5)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Neuer Eintrag in tt-tube, ...</p>
  </div>
</div>
`;

// #6: tt-tube -> Eigenschaften
const template6 = `
<div class="window modal-window" data-win="win6">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">tt-tube Eigenschaften (Fenster #6)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Eigenschaften...</p>
  </div>
</div>
`;

// #7: Kanal melden
const template7 = `
<div class="window modal-window" data-win="win7">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Kanal melden (Fenster #7)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Melde einen Kanal.</p>
  </div>
</div>
`;

// #8: Video melden
const template8 = `
<div class="window modal-window" data-win="win8">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Video melden (Fenster #8)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Video-Meldung hier...</p>
  </div>
</div>
`;

// #9: tt-observ -> Eigenschaften
const template9 = `
<div class="window modal-window" data-win="win9">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">tt-observ Eigenschaften (Fenster #9)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Eigenschaften von tt-observ...</p>
  </div>
</div>
`;

// #10: tt-observ -> Suche (iframe)
const template10 = `
<div class="window modal-window" data-win="win10" style="width:800px; height:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Suche (Fenster #10)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <iframe src="https://tricktok.afd-verbot.de/suche" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

// #11: Kanal melden
const template11 = `
<div class="window modal-window" data-win="win11">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Kanal melden (Fenster #11)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Kanal melden in tt-observ...</p>
  </div>
</div>
`;

// #12: Logo
const template12 = `
<div class="window modal-window" data-win="win12">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Logo (Fenster #12)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="text-align:center;">
    <p>tt-observ Logo</p>
  </div>
</div>
`;

// #13: tt-sammler -> Neu
//   => Zeigt in iframe z.B. "/": Dann sieht man dort die DB-Liste & Form
//   => Oder Du machst eine separate Route "/sammler_modal"
const template13 = `
<div class="window modal-window" data-win="win13" style="width:800px; height:600px;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">TT-Sammler </h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <!-- Iframe lädt /tt_sammler_input -->
    <iframe src="/tt_sammler_input" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;

// #14..#17: Subfenster, falls man im Verzeichnis (#1) etwas anklickt
const template14 = `
<div class="window modal-window" data-win="win18" style="width:1200px !important; height:auto !important;">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">AfD Wortwolke</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="text-align:center;">
    <img src="/static/wolke.png" alt="Logo" style="max-width:100% !important; height:auto !important;">
  </div>
</div>
`;


const template15 = `
<div class="window modal-window" data-win="win15">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Eintrag B (Fenster #15)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Detail zu Eintrag B.</p>
  </div>
</div>
`;
const template16 = `
<div class="window modal-window" data-win="win16">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Eintrag C (Fenster #16)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Detail zu Eintrag C.</p>
  </div>
</div>
`;
const template17 = `
<div class="window modal-window" data-win="win17">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Eintrag D (Fenster #17)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Detail zu Eintrag D.</p>
  </div>
</div>
`;

// #18: Logo (für tt-sammler Ansicht->Logo)
const template18 = `
<div class="window modal-window" data-win="win18">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Logo (Fenster #18)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="text-align:center;">
    <img src="/static/banderole2.png" alt="Logo" style="max-width:100%; height:auto;">
  </div>
</div>
`;

// #19 => TT-Sammler Neu
const template19 = `
<div class="window modal-window" data-win="win19" style="width:800px; height:600px;">
  <div class="title-bar" style="justify-content: space-between;">
    <h1 class="title">TT-Sammler (Fenster #19)</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane" style="width:100%; height:calc(100% - 2rem); padding:0;">
    <!-- iframe => /tt_sammler_db -->
    <iframe src="/tt_sammler_db" style="width:100%; height:100%; border:none;"></iframe>
  </div>
</div>
`;


const template20 = `
<div class="window modal-window" data-win="win20">
  <div class="title-bar" style="justify-content:space-between;">
    <h1 class="title">Fenster #20</h1>
    <span class="close">[x]</span>
  </div>
  <div class="window-pane">
    <p>Platzhalter #20</p>
  </div>
</div>
`;

/***********************************************
 * createWindow() - Fenster erstellen
 ***********************************************/
function createWindow(template, windowKey) {
  if (openedWindows[windowKey]) {
    return; // Schon offen
  }
  openedWindows[windowKey] = true;

  const wrapper = document.createElement('div');
  wrapper.innerHTML = template.trim();
  const modalEl = wrapper.firstElementChild;

  // Z-Index
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
  }

  // Klick => nach vorne
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

  // Spezialfall: Im Verzeichnis-Fenster #1 => Links, die neue Fenster öffnen
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
 * getTemplate()
 ***********************************************/
function getTemplate(key) {
  switch (key) {
    case 'window1':  return template1;
    case 'window2':  return template2;
    case 'window3':  return template3;
    case 'window4':  return template4;
    case 'window5':  return template5;
    case 'window6':  return template6;
    case 'window7':  return template7;
    case 'window8':  return template8;
    case 'window9':  return template9;
    case 'window10': return template10;
    case 'window11': return template11;
    case 'window12': return template12;
    case 'window13': return template13;
    case 'window14': return template14;
    case 'window15': return template15;
    case 'window16': return template16;
    case 'window17': return template17;
    case 'window18': return template18;
    case 'window19': return template19;
    case 'window20': return template20;
    default:
      return template2; // Fallback
  }
}

/***********************************************
 * App-Start
 ***********************************************/
const modalContainer = document.getElementById('modalContainer');

// Icons => Fenster #1 / #2
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

// Beispiel: Menüs => #3, #4, #5, #6, ...
const btn3 = document.getElementById('openWindow3');
if (btn3) { btn3.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window3'), 'window3'); }); }

const btn4 = document.getElementById('openWindow4');
if (btn4) { btn4.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window4'), 'window4'); }); }

const btn5 = document.getElementById('openWindow5');
if (btn5) { btn5.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window5'), 'window5'); }); }

const btn6 = document.getElementById('openWindow6');
if (btn6) { btn6.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window6'), 'window6'); }); }

const btn7 = document.getElementById('openWindow7');
if (btn7) { btn7.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window7'), 'window7'); }); }

const btn8 = document.getElementById('openWindow8');
if (btn8) { btn8.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window8'), 'window8'); }); }

const btn9 = document.getElementById('openWindow9');
if (btn9) { btn9.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window9'), 'window9'); }); }

const btn10 = document.getElementById('openWindow10');
if (btn10) { btn10.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window10'), 'window10'); }); }

const btn11 = document.getElementById('openWindow11');
if (btn11) { btn11.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window11'), 'window11'); }); }

const btn12 = document.getElementById('openWindow12');
if (btn12) { btn12.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window12'), 'window12'); }); }

const btn13 = document.getElementById('openWindow13');
if (btn13) { btn13.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window13'), 'window13'); }); }

const btn18 = document.getElementById('openWindow18');
if (btn18) { btn18.addEventListener('click', e => { e.preventDefault(); createWindow(getTemplate('window18'), 'window18'); }); }

const btn19 = document.getElementById('openWindow19');
if (btn19) {
  btn19.addEventListener('click', (e) => {
    e.preventDefault();
    createWindow(getTemplate('window19'), 'window19');
  });
}

// Beim Start => vorhandene Fenster laden
document.addEventListener('DOMContentLoaded', () => {
  loadWindowState();
  for (const key in windowState) {
    if (windowState.hasOwnProperty(key)) {
      createWindow(getTemplate(key), key);
    }
  }
});

// Beispiel: Export-Link-Cooldown
const exportLink = document.getElementById('exportLink');
if (exportLink) {
  exportLink.addEventListener('click', (e) => {
    exportLink.style.pointerEvents = 'none';
    exportLink.style.opacity = '0.5';
    setTimeout(() => {
      exportLink.style.pointerEvents = 'auto';
      exportLink.style.opacity = '1';
    }, 30000);
  });
}
