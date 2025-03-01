/* Neutral, ohne Personalpronomen. */
const {
  Engine,
  Render,
  Runner,
  Composite,
  Bodies,
  Body,
  Common,
  Mouse,
  MouseConstraint,
  Events
} = Matter;

// Engine & World
const engine = Engine.create();
const world = engine.world;
engine.gravity.y = 0.3;
// Vollbild
let width = window.innerWidth;
let height = window.innerHeight;

// Canvas erzeugen
const canvas = document.createElement("canvas");
canvas.id = "worldCanvas";
document.body.appendChild(canvas);

// Renderer
const render = Render.create({
  canvas: canvas,
  engine: engine,
  options: {
    width: width,
    height: height,
    wireframes: false,
    background: "#ffffff",
    showBounds: false
  }
});

// Runner
const runner = Runner.create();
Runner.run(runner, engine);
Render.run(render);

// Resize => Canvas und Wände anpassen
window.addEventListener("resize", () => {
  width = window.innerWidth;
  height = window.innerHeight;
  render.options.width = width;
  render.options.height = height;
  canvas.width = width;
  canvas.height = height;
  updateWalls();
});

// Keine Boden-Kollision: Nur Wände links + rechts
// => Bilder fallen nach unten aus dem Bildbereich raus

let leftWall, rightWall;

function createWalls() {
  // Obere Wand ist entfernt, Boden ist entfernt
  // => Nur linke + rechte Wand
  leftWall = Bodies.rectangle(-25, height / 2, 50, height * 2, { isStatic: true });
  rightWall = Bodies.rectangle(width + 25, height / 2, 50, height * 2, { isStatic: true });
  Composite.add(world, [leftWall, rightWall]);
}

function removeWalls() {
  Composite.remove(world, leftWall);
  Composite.remove(world, rightWall);
}

function updateWalls() {
  removeWalls();
  createWalls();
}

createWalls();

// Maus + Constraint => Greifen möglich
const mouse = Mouse.create(render.canvas);
const mouseConstraint = MouseConstraint.create(engine, {
  mouse: mouse,
  constraint: {
    stiffness: 0.5,
    render: { visible: false }
  }
});
Composite.add(world, mouseConstraint);
render.mouse = mouse;

/**
 * Fotos-Array
 */
const photoBodies = [];
const maxCount = 150; // maximale Anzahl gleichzeitig

// Globale (feste) Skalierung => Bilder sehr klein
let currentGlobalScale = 0.15;

/**
 * boundingBoxFactor => vergrößert die Kollision
 * => leichteres Anklicken
 */
const boundingBoxFactor = 10.4;

/**
 * Bilder hinzufügen => periodisch, kein Button
 */
function addPhotoBodies(urls) {
  urls.forEach(url => {
    // Zufällige Basisgröße (z. B. 80..160 px)
    const baseW = Common.random(80, 160);
    const baseH = Common.random(60, baseW);

    // Kollisions-Box (wird später skaliert)
    const bodyW = Math.floor(baseW * boundingBoxFactor);
    const bodyH = Math.floor(baseH * boundingBoxFactor);

    const halfW = bodyW / 2;
    const halfH = bodyH / 2;

    // Position => leicht oberhalb des sichtbaren Bereichs
    // => Damit Bild ins Bildfeld fällt
    // z. B. y = - (halfH + 50)
    // => wenn boundingBoxFactor groß, kann halfH mehrere hundert Pixel sein
    const xPos = Common.random(halfW + 50, width - halfW - 50);
    const yPos = - (halfH + 50);

    // Matter-Body
    const body = Bodies.rectangle(xPos, yPos, bodyW, bodyH, {
      restitution: 0.7,
      frictionAir: 0.01,
      render: {
        sprite: {
          texture: url
        }
      }
    });

    // Plugin => Infos für Skalierung
    body.plugin = {
      baseWidth: baseW,
      baseHeight: baseH,
      boxWidth: bodyW,
      boxHeight: bodyH,
      localScale: 1.0
    };

    // Skalierung anwenden (0.15)
    applyScaleToBody(body, currentGlobalScale);

    Composite.add(world, body);
    photoBodies.push(body);
  });

  // Limitierung
  while (photoBodies.length > maxCount) {
    const oldest = photoBodies.shift();
    Composite.remove(world, oldest);
  }
}

/**
 * applyScaleToBody => skaliert Kollision + Sprite
 */
function applyScaleToBody(body, newScale) {
  const oldScale = body.plugin.localScale;
  const ratio = newScale / oldScale;

  Body.scale(body, ratio, ratio);

  const spr = body.render.sprite;
  if (spr) {
    const oldX = spr.xScale || 1;
    const oldY = spr.yScale || 1;
    spr.xScale = oldX * ratio;
    spr.yScale = oldY * ratio;
  }

  body.plugin.localScale = newScale;
}

// Periodischer Spawn: z. B. alle 2 Sekunden
const spawnIntervalMs = 2000;
setInterval(() => {
  // 5 Bilder auf einmal
  fetch("./random?count=5")
    .then(r => r.json())
    .then(data => addPhotoBodies(data))
    .catch(err => console.error("Fehler /random:", err));
}, spawnIntervalMs);

// Option: Entfernen, sobald Bild weit unten raus ist
Events.on(engine, "afterUpdate", () => {
  for (let i = photoBodies.length - 1; i >= 0; i--) {
    const b = photoBodies[i];
    // z. B. wenn der Mittelpunkt unterhalb des Bildrands + Puffer
    if (b.position.y > height + 300) {
      Composite.remove(world, b);
      photoBodies.splice(i, 1);
    }
  }
});
