/* Neutral, ohne Personalpronomen. */
const express = require("express");
const path = require("path");
const fs = require("fs");

const PORT = 4050;

// Verzeichnis mit den Bildern anpassen
const ROOT_DIR = "/mnt/HC_Volume_101955489/gallery-dl/tiktok"; 

const app = express();
app.use(express.static(path.join(__dirname, "public")));

let allFiles = [];

/**
 * Rekursive Suche nach .jpg, .jpeg, .png, .gif
 */
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

// /random?count=... => Zufällige Bildpfade
app.get("/random", (req, res) => {
  const count = parseInt(req.query.count) || 5;
  if (!allFiles.length) {
    return res.json([]);
  }

  const results = [];
  for (let i = 0; i < count; i++) {
    const idx = Math.floor(Math.random() * allFiles.length);
    const filePath = allFiles[idx];
    const relative = path.relative(ROOT_DIR, filePath);
    // Sonderzeichen encoden (z. B. #, Leerzeichen)
    const segments = relative.split(path.sep).map(encodeURIComponent);
    const encoded = segments.join("/");
    results.push("/tiktok/" + encoded);
  }

  res.json(results);
});

// Statische Auslieferung unter /tiktok
app.use(
  "/tiktok",
  express.static(ROOT_DIR, {
    fallthrough: false
  })
);

// Start
app.listen(PORT, () => {
  console.log(`Server läuft auf Port ${PORT}`);
});
