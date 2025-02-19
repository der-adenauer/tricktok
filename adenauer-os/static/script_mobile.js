// script_mobile.js

// Diese mobile JS-Datei arbeitet mit nur einem Vollbild-Modal,
// anstatt vieler Fenster wie im Desktop-Modus (script.js).
// Jede Icon-Aktion öffnet ein Fullscreen-Overlay (Modal) mit ggf. einem iframe.

document.addEventListener("DOMContentLoaded", () => {
  const systemTimeEl = document.getElementById("systemTime");

  function updateSystemTime() {
    if (!systemTimeEl) return;
    const now = new Date();
    const hh = String(now.getHours()).padStart(2,"0");
    const mm = String(now.getMinutes()).padStart(2,"0");
    const ss = String(now.getSeconds()).padStart(2,"0");
    systemTimeEl.textContent = hh + ":" + mm + ":" + ss;
  }
  setInterval(updateSystemTime, 1000);
  updateSystemTime();

  // --------------------------------------------------------
  // Menü-Buttons (System -> Hilfe, Programmquelle, Kontakt)
  // --------------------------------------------------------

  // 1) Hilfe (öffnen via /hilfe_extended im iFrame)
  const btn3 = document.getElementById('openWindow3');
  if (btn3) {
    btn3.addEventListener('click', (e) => {
      e.preventDefault();
      openFullScreenModal("/hilfe_extended", "Hilfe");
    });
  }

  // 2) Programmquelle (statisches HTML)
  const btn4 = document.getElementById('openWindow4');
  if (btn4) {
    btn4.addEventListener('click', (e) => {
      e.preventDefault();
      // Inhalt des Fensters "Programmquelle" wird hier per HTML-String eingefügt
      openFullScreenModal(null, "Programmquelle", `
        <div style="padding:1rem;">
          <h2>Adenauer OS <br> Projekt Tricktok</h2>
          <p>Adenauer OS ist ein Mehrbenutzer-Betriebssystem, 
             dafür entwickelt, rechtsextreme Inhalte auf TikTok zu identifizieren.</p>
          <p>Version: v.02 | Buildnummer: 1933.1</p>
          <img src="/static/qrcodegithub.png" alt="github" 
               style="transform: scale(1); width:auto; height:auto; max-width:none; max-height:none;">
        </div>
      `);
    });
  }

  // 3) Kontakt (statisches HTML — entspricht template20 im Desktop)
  const btn20 = document.getElementById('openWindow20');
  if (btn20) {
    btn20.addEventListener('click', (e) => {
      e.preventDefault();
      // Anstatt /contact einfach direkt das HTML von template20
      openFullScreenModal(null, "Kontakt", `
        <div style="padding:1rem; text-align:center;">
          <br><br>
          <p>
            adenauer@tutamail.com<br>
            der-adenauer.de
          </p>
        </div>
      `);
    });
  }

  // --------------------------------------------------------
  // Desktop-Icons -> Mobile-Fullscreen (jeweils 1 Modal-Fenster)
  // --------------------------------------------------------

  // Icon6 (Index) => im Desktop "window1". Hier mobile: Statisches HTML
  const icon6 = document.getElementById('icon6');
  if (icon6) {
    icon6.addEventListener('click', () => {
      // Beispiel: Index-Liste. Zum Teil verlinken wir hier 
      // mit `mobile-entry`, um das an unser Delegations-Event zu binden
      openFullScreenModal(null, "Index", `
        <div style="padding:1rem;">
          <p>Verzeichnis</p>
          <ul>
            <!-- Hashtag - Wortwolke (Bild) -->
            <li>
              <a href="#" 
                 class="mobile-entry" 
                 data-src="/static/wolke.png" 
                 data-title="Hashtag - Wortwolke" 
                 data-iframe="false">
                 Hashtag - Wortwolke
              </a>
            </li>
            <!-- Logo (Bild) -->
            <li>
              <a href="#" 
                 class="mobile-entry" 
                 data-src="/static/banderole2.png" 
                 data-title="Logo" 
                 data-iframe="false">
                 Logo
              </a>
            </li>
            <!-- Anweisungen zu Datenfilterung (iframe) -->
            <li>
              <a href="#" 
                 class="mobile-entry" 
                 data-iframe="true" 
                 data-src="/metadatenfilter" 
                 data-title="Anweisungen zu Datenfilterung">
                 Anweisungen zu Datenfilterung
              </a>
            </li>
            <!-- Anweisungen zu Telearbeit (hier: statisches HTML aus template17) -->
            <li>
              <a href="#" 
                 class="mobile-entry-telearbeit" 
                 data-title="Anweisungen zu Telearbeit">
                 Anweisungen zu Telearbeit
              </a>
            </li>
          </ul>
        </div>
      `);
    });
  }

  // Icon7 (Benutzerkonto) => fetch benutzer_info + session_name
  const icon7 = document.getElementById('icon7');
  if (icon7) {
    icon7.addEventListener('click', () => {
      fetch('/benutzer_info')
        .then(response => response.text())
        .then(agentInfo => {
          return fetch('/session_name')
            .then(r => r.text())
            .then(name => ({
              agentInfo: agentInfo,
              name: name
            }));
        })
        .then(data => {
          openFullScreenModal(null, "Benutzerkonto", `
            <div style="padding:1rem;">
              <div style="display:flex; align-items:center;">
                <img src="/static/icon7.png" alt="icon7" width="64" height="64">
                <span style="font-size:1.2rem; font-weight:bold; margin-left:10px;">
                  ${data.name}
                </span>
              </div>
              <p>Infos zum angemeldeten Benutzer:</p>
              <div style="font-size:0.8rem; color:#666;">${data.agentInfo}</div>
            </div>
          `);
        })
        .catch(err => {
          console.error(err);
        });
    });
  }

  // Icon8 (Fahndungsliste) => /fahndungsliste_db
  const icon8 = document.getElementById('icon8');
  if (icon8) {
    icon8.addEventListener('click', () => {
      openFullScreenModal("/fahndungsliste_db", "Fahndungsliste");
    });
  }

  // Icon9 (Tricktok-Suche) => externe Domain
  const icon9 = document.getElementById('icon9');
  if (icon9) {
    icon9.addEventListener('click', () => {
      openFullScreenModal("https://tricktok.afd-verbot.de/suche", "Tricktok-Suche", null, true);
    });
  }

  // Icon10 (Archiv)
  const icon10 = document.getElementById('icon10');
  if (icon10) {
    icon10.addEventListener('click', () => {
      openFullScreenModal("https://py.afd-verbot.de/tricktok-archiv/", "Archiv", null, true);
    });
  }

  // Icon12 (Statistiktok)
  const icon12 = document.getElementById('icon12');
  if (icon12) {
    icon12.addEventListener('click', () => {
      openFullScreenModal("https://py.afd-verbot.de/statistiktok", "Statistiktok", null, true);
    });
  }

  // Icon13 (Video Feature)
  const icon13 = document.getElementById('icon13');
  if (icon13) {
    icon13.addEventListener('click', () => {
      openFullScreenModal("/video_feature", "Player");
    });
  }

  // Icon14 (Nachrichten)
  const icon14 = document.getElementById('icon14');
  if (icon14) {
    icon14.addEventListener('click', () => {
      openFullScreenModal("https://neuters.de/search?query=tiktok", "Nachrichten", null, true);
    });
  }

  // Icon15 (Bilder-Archiv)
  const icon15 = document.getElementById('icon15');
  if (icon15) {
    icon15.addEventListener('click', () => {
      openFullScreenModal("https://py.afd-verbot.de/tiktok/", "Bilder-Archiv", null, true);
    });
  }

  // Icon16 (Gallery Feature -> /gallery_feature)
  const icon16 = document.getElementById('icon16');
  if (icon16) {
    icon16.addEventListener('click', () => {
      openFullScreenModal("/gallery_feature", "Gallery Feature", null, true);
    });
  }

  // OPTIONAL: Icon17 (Zeitreihen) - analog zum Desktop-Fenster window24
  const icon17 = document.getElementById('icon17');
  if (icon17) {
    icon17.addEventListener('click', () => {
      // z.B. Zeitreihen -> https://py.afd-verbot.de/zeitreihen/
      openFullScreenModal("https://py.afd-verbot.de/zeitreihen/", "Zeitreihen", null, true);
    });
  }

  // Optional: Icon21 (Kleiner Max)
  const icon21 = document.getElementById('icon21');
  if (icon21) {
    icon21.addEventListener('click', () => {
      // Snippet analog zu template21 (Kleiner Max)
      openFullScreenModal(null, "Kleiner Max", `
        <iframe src="https://archive.afd-verbot.de/videos/embed/b666e9c0-d5ae-4817-b120-3ae0fe949576?start=16s"
                style="width:100%; height:calc(100% - 2rem); border:none;"
                allowfullscreen=""
                sandbox="allow-same-origin allow-scripts allow-popups allow-forms">
        </iframe>
      `, false);
    });
  }

  // --------------------------------------------------------
  // Delegation für Einträge innerhalb des "Index"-Modals
  // --------------------------------------------------------
  // 1) "mobile-entry" => kann Bilder oder iframe laden
  // 2) "mobile-entry-telearbeit" => spezieller Klick für "Anweisungen zu Telearbeit" (template17)
  document.body.addEventListener('click', (e) => {
    // A) "mobile-entry"
    if (e.target.classList && e.target.classList.contains('mobile-entry')) {
      e.preventDefault();
      const src = e.target.dataset.src || "";
      const title = e.target.dataset.title || "Vollbild";
      const isIframe = e.target.dataset.iframe === "true";
      if (isIframe) {
        // iframe laden
        openFullScreenModal(src, title, null, true);
      } else {
        // Bild
        const contentHtml = `
          <div style="width:100%; text-align:center;">
            <img src="${src}" alt="${title}" style="max-width:100%; max-height:calc(100vh - 100px);" />
          </div>
        `;
        openFullScreenModal(null, title, contentHtml);
      }
    }

    // B) "mobile-entry-telearbeit" => direkter Snippet für template17
    if (e.target.classList && e.target.classList.contains('mobile-entry-telearbeit')) {
      e.preventDefault();
      const title = e.target.dataset.title || "Anweisungen zu Telearbeit";
      // Hier das HTML aus template17 (desktop) sinngemäß:
      openFullScreenModal(null, title, `
        <div style="padding:1rem;">
          <h2>Anweisungen zu Telearbeit</h2>
          <p>
            Die Ausübung dienstlicher Tätigkeiten im Rahmen der Telearbeit, 
            sei es von der häuslichen Arbeitsstätte oder einem anderen entfernten Standort aus, 
            ist ausschließlich unter Zuhilfenahme der hierfür vorgesehenen Plattform durchzuführen.
          </p>
          <p>
            Für die parallele Nutzung der TikTok-App auf einem mobilen Endgerät 
            erweist sich dieses Verfahren als besonders zweckmäßig.
            Sollte bei der Sichtung verdächtiger Inhalte ein erhöhtes Gefährdungspotential erkannt werden, 
            wird ausdrücklich angeordnet, den entsprechenden Kanal umgehend 
            und unter Nutzung der zentralen Fahndungsliste zu melden.
          </p>
          <center>
            <img src="/static/qrcodefahndung.png" alt="QR-Code Fahndungsliste"
                 style="transform: scale(1); width:auto; height:auto; max-width:none; max-height:none;">
          </center>
        </div>
      `);
    }
  });
});

/**
 * Zeigt ein Vollbild-Overlay (Modal) mit optionaler iframe-Quelle oder statischem HTML-Inhalt.
 *
 * @param {string|null} srcUrl - Falls vorhanden, wird dieser Pfad in ein iframe geladen
 *                               (z.B. "/hilfe_extended" oder "https://...").
 * @param {string} headline - Titelzeile im Modal.
 * @param {string|null} contentHtml - Falls wir statisches HTML anzeigen wollen (z.B. Kontakt-Infos).
 * @param {boolean} forceIframe - ob wir unbedingt ein iframe nutzen (etwa bei externen URLs).
 */
function openFullScreenModal(srcUrl, headline, contentHtml=null, forceIframe=false) {
  // Vorhandenes Modal entfernen, nur 1 Fenster gleichzeitig
  const existingModal = document.getElementById("mobileFullscreenModal");
  if (existingModal) {
    existingModal.remove();
  }

  const overlay = document.createElement("div");
  overlay.id = "mobileFullscreenModal";
  overlay.style.position = "fixed";
  overlay.style.top = "0";
  overlay.style.left = "0";
  overlay.style.width = "100%";
  overlay.style.height = "100%";
  overlay.style.backgroundColor = "#fff";
  overlay.style.zIndex = "9999";

  // Schließen-Button
  const closeBtn = document.createElement("div");
  closeBtn.style.position = "absolute";
  closeBtn.style.right = "10px";
  closeBtn.style.top = "10px";
  closeBtn.style.zIndex = "10000";
  closeBtn.style.cursor = "pointer";
  closeBtn.style.fontSize = "1.2rem";
  closeBtn.innerHTML = "✕";
  closeBtn.addEventListener('click', () => {
    overlay.remove();
  });

  // Title bar
  const titleBar = document.createElement("div");
  titleBar.style.backgroundColor = "#e1e1e1";
  titleBar.style.height = "40px";
  titleBar.style.display = "flex";
  titleBar.style.alignItems = "center";
  titleBar.style.justifyContent = "center";
  titleBar.style.position = "relative";

  const h1 = document.createElement("h1");
  h1.textContent = headline || "Mobile Modal";
  h1.style.fontSize = "1.2rem";
  h1.style.margin = "0";
  titleBar.appendChild(h1);

  // Content-Bereich
  const contentArea = document.createElement("div");
  contentArea.style.position = "absolute";
  contentArea.style.top = "40px";
  contentArea.style.left = "0";
  contentArea.style.width = "100%";
  contentArea.style.bottom = "0";
  contentArea.style.overflow = "auto";

  // 1) Falls wir statisches HTML haben:
  if (contentHtml) {
    contentArea.innerHTML = contentHtml;

  // 2) Falls wir eine srcUrl haben (iframe), oder "forceIframe == true"
  } else if (srcUrl && (forceIframe || srcUrl.startsWith("http") || srcUrl.startsWith("/"))) {
    const iframe = document.createElement("iframe");
    iframe.src = srcUrl;
    iframe.style.width = "100%";
    iframe.style.height = "100%";
    iframe.style.border = "none";
    contentArea.appendChild(iframe);
  }

  // In DOM einhängen
  overlay.appendChild(titleBar);
  overlay.appendChild(closeBtn);
  overlay.appendChild(contentArea);
  document.body.appendChild(overlay);
}
