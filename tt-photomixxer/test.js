#!/usr/bin/env node
// dateiname: test-fetch-images.js

const fetch = require("node-fetch");
const cheerio = require("cheerio");

// Hier die URL, von der Auto-Index oder HTML mit Links kommt:
const REMOTE_GALLERY_URL = "https://py.afd-verbot.de/tiktok/";

async function testFetch() {
  try {
    const response = await fetch(REMOTE_GALLERY_URL);
    const text = await response.text();

    // Auskommentieren, um das gesamte HTML zu sehen:
    // console.log(text);

    const $ = cheerio.load(text);
    const found = [];

    $("a").each((_, el) => {
      const href = $(el).attr("href");
      if (!href) return;
      const lower = href.toLowerCase();
      if (
        lower.endsWith(".jpg") ||
        lower.endsWith(".jpeg") ||
        lower.endsWith(".png") ||
        lower.endsWith(".gif")
      ) {
        found.push(href);
      }
    });

    console.log("Gefundene Bilder:", found.length);
    console.log(found);
  } catch (err) {
    console.error("Fehler beim Abruf:", err);
  }
}

testFetch();
