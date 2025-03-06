/* Neutral, ohne Personalpronomen. */
const express = require("express");
const path = require("path");
const fs = require("fs");

const PORT = 4001;
const ROOT_DIR = "/mnt/HC_Volume_101955489/gallery-dl/tiktok"; // Anpassen

const app = express();

// Statisches Verzeichnis => public (index.html + app.js)
app.use(express.static(path.join(__dirname, "public")));

// index.html ausliefern
app.get("/", (req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

// Alle Bilddateien erfassen
let allFiles = [];

function scanDirectoryRecursively(dir) {
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const ent of entries) {
    const fullPath = path.join(dir, ent.name);
    if (ent.isDirectory()) {
      scanDirectoryRecursively(fullPath);
    } else {
      const lower = ent.name.toLowerCase();
      if (
        lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".gif")
      ) {
        allFiles.push(fullPath);
      }
    }
  }
}

console.log("Scanne Verzeichnis:", ROOT_DIR);
scanDirectoryRecursively(ROOT_DIR);
console.log("Gefundene Bilder:", allFiles.length);

// Route /random => Zufällige Bildpfade
app.get("/random", (req, res) => {
  const count = parseInt(req.query.count) || 5;
  if (allFiles.length === 0) {
    return res.json([]);
  }

  const results = [];
  for (let i = 0; i < count; i++) {
    const idx = Math.floor(Math.random() * allFiles.length);
    const filePath = allFiles[idx];
    // Relativer Pfad
    const relative = path.relative(ROOT_DIR, filePath);
    // Sonderzeichen escapen
    const segments = relative.split(path.sep).map(encodeURIComponent);
    const encoded = segments.join("/");
    // Zugriff via /tiktok/...
    results.push("/tiktok/" + encoded);
  }

  res.json(results);
});

// Statisches Serven der Bilddateien unter /tiktok
app.use(
  "/tiktok",
  express.static(ROOT_DIR, {
    fallthrough: false
  })
);

// Start
app.listen(PORT, () => {
  console.log("Server läuft auf Port " + PORT);
});
