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
  MouseConstraint
} = Matter;

// Engine & World
const engine = Engine.create();
const world = engine.world;

// Vollbild
let width = window.innerWidth;
let height = window.innerHeight;

// Canvas
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
    showBounds: true  // bounding box anzeigen
  }
});

// Runner
const runner = Runner.create();
Runner.run(runner, engine);
Render.run(render);

// Resize => Canvas & Wände anpassen
window.addEventListener("resize", () => {
  width = window.innerWidth;
  height = window.innerHeight;
  render.options.width = width;
  render.options.height = height;
  canvas.width = width;
  canvas.height = height;
  updateWalls();
});

// Wände
let floor, ceiling, leftWall, rightWall;

function createWalls() {
  floor = Bodies.rectangle(width / 2, height + 25, width * 2, 50, { isStatic: true });
  ceiling = Bodies.rectangle(width / 2, -25, width * 2, 50, { isStatic: true });
  leftWall = Bodies.rectangle(-25, height / 2, 50, height * 2, { isStatic: true });
  rightWall = Bodies.rectangle(width + 25, height / 2, 50, height * 2, { isStatic: true });
  Composite.add(world, [floor, ceiling, leftWall, rightWall]);
}

function removeWalls() {
  Composite.remove(world, floor);
  Composite.remove(world, ceiling);
  Composite.remove(world, leftWall);
  Composite.remove(world, rightWall);
}

function updateWalls() {
  removeWalls();
  createWalls();
}

createWalls();

// Maus + Constraint => sehr hoher stiffness => besseres Greifen
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
 * Fotos
 */
const photoBodies = [];
const maxCount = 50;

// Globale Skala (Start = 0.15 laut slider)
let currentGlobalScale = 0.15;

/**
 * boundingBoxFactor => vergrößert die Kollision
 * => leichteres Anklicken
 */
const boundingBoxFactor = 10.4;

/**
 * Bilder hinzufügen
 * => direkter Spawn, 
 * => Start-Skalierung = 0.15
 */
function addPhotoBodies(urls) {
  urls.forEach(url => {
    const baseW = Common.random(80, 160);
    const baseH = Common.random(60, baseW);
    const bodyW = Math.floor(baseW * boundingBoxFactor);
    const bodyH = Math.floor(baseH * boundingBoxFactor);

    const halfW = bodyW / 2;
    const halfH = bodyH / 2;

    // Randabstand => 50 px
    const xPos = Common.random(halfW + 50, width - halfW - 50);
    const yPos = Common.random(halfH + 50, height - halfH - 200);

    const body = Bodies.rectangle(xPos, yPos, bodyW, bodyH, {
      restitution: 0.7,
      frictionAir: 0.01,
      render: {
        sprite: {
          texture: url
        }
      }
    });

    body.plugin = {
      baseWidth: baseW,
      baseHeight: baseH,
      boxWidth: bodyW,
      boxHeight: bodyH,
      localScale: 1.0
    };

    // sofort an currentGlobalScale anpassen
    applyScaleToBody(body, currentGlobalScale);

    Composite.add(world, body);
    photoBodies.push(body);
  });

  // Limit maxCount
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

/**
 * Setzt globale Skala
 */
function setGlobalScale(val) {
  photoBodies.forEach(b => applyScaleToBody(b, val));
  currentGlobalScale = val;
}

/**
 * "Runter spülen": Boden weg => Bilder raus => Cleanup => Boden wieder
 */
function runSpuelen() {
  Composite.remove(world, floor);
  setTimeout(() => {
    photoBodies.forEach(b => Composite.remove(world, b));
    photoBodies.length = 0;
    Composite.add(world, floor);
  }, 1200);
}

/* === UI === */
const btnNachlegen = document.getElementById("btnNachlegen");
btnNachlegen.addEventListener("click", () => {
  fetch("./random?count=5")
    .then(r => r.json())
    .then(data => addPhotoBodies(data))
    .catch(err => console.error("Fehler /random:", err));
});

const btnSpuelen = document.getElementById("btnSpuelen");
btnSpuelen.addEventListener("click", runSpuelen);

const scaleSlider = document.getElementById("scaleSlider");
const scaleLabel = document.getElementById("scaleLabel");

// Startwert laut index.html => 0.15
scaleLabel.textContent = scaleSlider.value;

// Beim Ändern => setGlobalScale
scaleSlider.addEventListener("input", e => {
  const val = parseFloat(e.target.value);
  scaleLabel.textContent = val.toFixed(2);
  setGlobalScale(val);
});

/** 
 * Direkt beim Start => 
 * automatische "Nachlegen" 
 * => 5 Bilder spawnen schon beim Seitenaufruf
 */
window.addEventListener("load", () => {
  fetch("./random?count=5")
    .then(r => r.json())
    .then(data => addPhotoBodies(data))
    .catch(err => console.error("Fehler /random (Startup):", err));
});