// Mobile-Logik ohne Desktop-Fenster.
// Statt vieler Fenster nur ein zentrales Modal im Vollbild.
// Close-Button ermöglicht Schließen. 
// Beispielhafte Umsetzung.

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

  // Beispiel: Klick auf Menü -> Modal einblenden
  const btn3 = document.getElementById('openWindow3');
  const btn4 = document.getElementById('openWindow4');
  const btn20 = document.getElementById('openWindow20');

  if (btn3) {
    btn3.addEventListener('click', (e) => {
      e.preventDefault();
      openFullScreenModal("/hilfe_extended", "Hilfe");
    });
  }
  if (btn4) {
    btn4.addEventListener('click', (e) => {
      e.preventDefault();
      openFullScreenModal(null, "Programmquelle", `
        <div style="padding:1rem;">
          <h2>Adenauer OS <br> Projekt Tricktok</h2>
          <p>Adenauer OS ist ein Mehrbenutzer-Betriebssystem, dafür entwickelt, rechtsextreme Inhalte auf TikTok zu identifizieren.</p>
          <p>Version: v.02 | Buildnummer: 1933.1</p>
          <img src="/static/qrcodegithub.png" alt="github" style="transform: scale(1); width:auto; height:auto; max-width:none; max-height:none;">
        </div>
      `);
    });
  }
  if (btn20) {
    btn20.addEventListener('click', (e) => {
      e.preventDefault();
      openFullScreenModal("/contact", "Kontakt");
    });
  }

  // Icon-Beispiele (Index, Benutzer, Fahndung etc.)
  const icon6 = document.getElementById('icon6');
  if (icon6) {
    icon6.addEventListener('click', () => {
      openFullScreenModal(null, "Index", `
        <div style="padding:1rem;">
          <p>Verzeichnis</p>
          <ul>
            <li><a href="#" class="mobile-entry" data-src="/static/wolke.png" data-title="Hashtag - Wortwolke" data-iframe="false">Hashtag - Wortwolke</a></li>
            <li><a href="#" class="mobile-entry" data-src="/static/banderole2.png" data-title="Logo" data-iframe="false">Logo</a></li>
            <li><a href="#" class="mobile-entry" data-iframe="true" data-src="/metadatenfilter" data-title="Anweisungen zu Datenfilterung">Anweisungen zu Datenfilterung</a></li>
            <li><a href="#" class="mobile-entry" data-iframe="true" data-src="/hilfe_extended" data-title="Anweisungen zu Telearbeit">Anweisungen zu Telearbeit</a></li>
          </ul>
        </div>
      `);
    });
  }

  const icon7 = document.getElementById('icon7');
  if (icon7) {
    icon7.addEventListener('click', () => {
      // Benutzerinfo 
      // Erst User-Agent und Sessionname laden
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
                <span style="font-size:1.2rem; font-weight:bold; margin-left:10px;">${data.name}</span>
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

  const icon8 = document.getElementById('icon8');
  if (icon8) {
    icon8.addEventListener('click', () => {
      openFullScreenModal("/fahndungsliste_db", "Fahndungsliste");
    });
  }

  const icon9 = document.getElementById('icon9');
  if (icon9) {
    icon9.addEventListener('click', () => {
      // externer Link in Iframe
      openFullScreenModal("https://tricktok.afd-verbot.de/suche", "Tricktok-Suche", null, true);
    });
  }

  const icon10 = document.getElementById('icon10');
  if (icon10) {
    icon10.addEventListener('click', () => {
      openFullScreenModal("https://py.afd-verbot.de/tricktok-archiv/", "Archiv", null, true);
    });
  }

  const icon12 = document.getElementById('icon12');
  if (icon12) {
    icon12.addEventListener('click', () => {
      openFullScreenModal("https://py.afd-verbot.de/statistiktok", "Statistiktok", null, true);
    });
  }

  const icon13 = document.getElementById('icon13');
  if (icon13) {
    icon13.addEventListener('click', () => {
      openFullScreenModal("/video_feature", "Player");
    });
  }

  const icon14 = document.getElementById('icon14');
  if (icon14) {
    icon14.addEventListener('click', () => {
      openFullScreenModal("https://neuters.de/search?query=tiktok", "Nachrichten", null, true);
    });
  }

  // Delegation für dynamische Links in mobil-Modal
  document.body.addEventListener('click', (e) => {
    if (e.target.classList && e.target.classList.contains('mobile-entry')) {
      e.preventDefault();
      const src = e.target.dataset.src || "";
      const title = e.target.dataset.title || "Vollbild";
      const isIframe = e.target.dataset.iframe === "true";
      if (isIframe) {
        openFullScreenModal(src, title, null, true);
      } else {
        // Falls einfach ein Bild o.Ä. 
        const contentHtml = `
          <div style="width:100%; text-align:center;">
            <img src="${src}" alt="${title}" style="max-width:100%; max-height:calc(100vh - 100px);" />
          </div>
        `;
        openFullScreenModal(null, title, contentHtml);
      }
    }
  });
});

// Funktion öffnet Vollbild-Modal
function openFullScreenModal(srcUrl, headline, contentHtml, forceIframe=false) {
  // Vorhandenes Modal entfernen, nur ein Fenster gleichzeitig
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

  const closeBtn = document.createElement("div");
  closeBtn.className = "close";
  closeBtn.style.position = "absolute";
  closeBtn.style.right = "10px";
  closeBtn.style.top = "10px";
  closeBtn.style.zIndex = "10000";
  closeBtn.addEventListener('click', () => {
    overlay.remove();
  });

  // Title
  const titleBar = document.createElement("div");
  titleBar.style.backgroundColor = "#e1e1e1";
  titleBar.style.height = "40px";
  titleBar.style.display = "flex";
  titleBar.style.alignItems = "center";
  titleBar.style.justifyContent = "center";
  titleBar.style.position = "relative";
  const h1 = document.createElement("h1");
  h1.textContent = headline || "Mobile-Modal";
  h1.style.fontSize = "1.2rem";
  titleBar.appendChild(h1);

  // Content
  const contentArea = document.createElement("div");
  contentArea.style.position = "absolute";
  contentArea.style.top = "40px";
  contentArea.style.left = "0";
  contentArea.style.width = "100%";
  contentArea.style.bottom = "0";
  contentArea.style.overflow = "auto";

  if (contentHtml) {
    contentArea.innerHTML = contentHtml;
  } else if (srcUrl && (forceIframe || srcUrl.startsWith("http") || srcUrl.startsWith("/"))) {
    const iframe = document.createElement("iframe");
    iframe.src = srcUrl;
    iframe.style.width = "100%";
    iframe.style.height = "100%";
    iframe.style.border = "none";
    contentArea.appendChild(iframe);
  }

  overlay.appendChild(titleBar);
  overlay.appendChild(closeBtn);
  overlay.appendChild(contentArea);
  document.body.appendChild(overlay);
}
