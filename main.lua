-- main.lua — thin spine (B1) per docs/architecture.md.
-- Builds the shared `world`, registers modules in build order, drives their
-- load/update/draw(world, dt) hooks, and blits the base-res canvas (480x360)
-- to the window, nearest-upscaled and letterboxed (docs/viewport-camera.md).

local config = require("lib.config")

-- Ordered module registry — the thin-spine shape. Every entry exposes
-- load/update/draw(world, dt) and communicates only via the shared `world`
-- table (no cross-module requires); modules may also expose an optional
-- keypressed(world, key) hook (input lives in modules, per docs/architecture.md).
-- B1 shipped zero gameplay modules: config is a constants table, not a hook
-- module. Later tickets append one line each, in build order
-- (docs/backlog.md):
--   B6  require("lib.weapons"), require("lib.projectiles")
--   B9  require("lib.pickups")
--   B10 require("lib.run")
--   B11 require("lib.audio")
--   B12 require("lib.hud")
local modules = {
  require("lib.seeded"), -- B2: orders first — every later module draws from world.seeded
  require("lib.assets"), -- B3: sprite + sfx primitives, built once in load
  require("lib.map"),    -- B4: seeded floor gen + connectivity assert + tile batches
  require("lib.player"), -- B5: WASD movement + wall-slide (world.player)
  require("lib.camera"), -- B5: centered follow + world clamp + smoothing
  require("lib.weapons"),     -- B6: PULSE/SCATTER defs + fire (world.weapons)
  require("lib.projectiles"), -- B6: motion + wall/life death (world.projectiles)
  require("lib.enemy"),       -- B7: 3 archetypes + seeded per-room spawn (world.enemies)
  require("lib.combat"),      -- B8: damage flow — hits/HP/i-frames/kills (world.combat)
}

local world       -- shared state, built once in love.load
local canvas      -- base-res off-screen render target
local frameDt = 0 -- love.draw has no dt; forward the last update dt

local function buildWorld()
  world = {
    seed = config.DEBUG_SEED, -- consumed by lib/seeded's load()
    debug = true,             -- gates dev helpers (B2 readout, later debug-R)
    -- constants for modules (no cross-module requires; main is the single
    -- consumer of lib/config.lua and hands values over via world)
    TILE  = config.TILE,
    WORLD_W = config.MAPW, -- world pixel size (40 tiles x 16)
    WORLD_H = config.MAPH,
    VIEW_W  = config.VIEW_W, -- base-res canvas
    VIEW_H  = config.VIEW_H,
  }
end

-- B6.1 (ticket #26): Antecrypt look. One post pass built once in love.load — a
-- corner vignette image (drawn per frame, zero per-frame allocation). The
-- other measured cue, the period-2 scanline row texture, is baked into the
-- floor tile (lib/assets.lua) so UI text stays clean; neither is rebuilt per
-- frame (hard rule 5). world.fx data kept for the smoke to verify the shape.
local function buildFx()
  local W, H = config.VIEW_W, config.VIEW_H
  local vd = love.image.newImageData(W, H) -- alpha 0 center -> ~0.42 corners
  local cx, cy = W / 2, H / 2
  local maxD = math.sqrt(cx * cx + cy * cy)
  for y = 0, H - 1 do
    for x = 0, W - 1 do
      local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2) / maxD
      local a = math.max(0, (d - 0.45) / 0.55)
      vd:setPixel(x, y, 0, 0, 0, a * a * 0.42)
    end
  end
  world.fx = {
    vignette = love.graphics.newImage(vd),
    vignetteData = vd, -- ImageData kept for the smoke's shape check
  }
end

-- Temporary boot readout, restyled in B6.1 to Antecrypt's HUD language:
-- bright green top rule + title, white weapon/ammo info top-right, a filled
-- dark stats strip along the bottom with a bright border. lib/seeded adds the
-- dim-green RNG panel below the title; B12's real HUD replaces all of it.
local function drawBootReadout()
  local w, h = love.graphics.getDimensions()
  local scale = math.min(w / config.VIEW_W, h / config.VIEW_H)
  local DIM = { 0.28, 0.55, 0.33 } -- dim green secondary text
  local BR = { 0.45, 1.00, 0.58 }   -- bright green accents/rules

  -- canvas boundary, so the base-res edge reads against the black bars
  love.graphics.setColor(0.20, 0.45, 0.25, 0.6)
  love.graphics.rectangle("line", 0.5, 0.5, config.VIEW_W - 1, config.VIEW_H - 1)

  -- top rule + title (Antecrypt's top bright-bar language)
  love.graphics.setColor(BR[1], BR[2], BR[3], 0.9)
  love.graphics.rectangle("fill", 0, 0, config.VIEW_W, 1)
  love.graphics.setColor(BR[1], BR[2], BR[3], 1)
  love.graphics.print(config.TITLE:upper(), 8, 5)

  -- weapon/ammo readout, top-right, white (HUD info)
  if world.weapons and world.player.weapon then
    local d = world.weapons.DEFS[world.player.weapon]
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.format("%s ammo %d/%d  proj %d", d.name,
      world.player.ammo[world.player.weapon], d.max, #(world.projectiles or {})),
      320, 5)
  end

  -- bottom stats strip: dark fill + bright border + seed/cam/modules + canvas
  love.graphics.setColor(0.012, 0.05, 0.02, 1)
  love.graphics.rectangle("fill", 0, config.VIEW_H - 28, config.VIEW_W, 28)
  love.graphics.setColor(BR[1], BR[2], BR[3], 0.9)
  love.graphics.rectangle("fill", 0, config.VIEW_H - 29, config.VIEW_W, 1)
  love.graphics.setColor(0.50, 0.85, 0.55, 1)
  love.graphics.print(string.format("seed %s  kills %d  player (%.0f,%.0f)  cam (%.0f,%.0f)",
    world.seed, (world.run and world.run.kills) or 0,
    world.player.x, world.player.y, world.camera.x, world.camera.y),
    8, config.VIEW_H - 22)
  love.graphics.setColor(DIM[1], DIM[2], DIM[3], 1)
  love.graphics.print(string.format("canvas %dx%d -> window %dx%d (x%.2f)  modules %d/12",
    config.VIEW_W, config.VIEW_H, w, h, scale, #modules), 8, config.VIEW_H - 11)

  -- vignette (once-built corner darkening) last, over world + readout
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(world.fx.vignette, 0, 0)
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest") -- pixel-crisp upscale
  canvas = love.graphics.newCanvas(config.VIEW_W, config.VIEW_H)
  buildWorld()
  for _, m in ipairs(modules) do
    if m.load then m.load(world) end
  end
  buildFx()
end

function love.update(dt)
  frameDt = dt
  for _, m in ipairs(modules) do
    if m.update then m.update(world, dt) end
  end
end

function love.draw()
  -- 1) render the world into the base-res canvas (black field: B6.1 look)
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0, 0, 0, 1)
  for _, m in ipairs(modules) do
    if m.draw then m.draw(world, frameDt) end
  end
  drawBootReadout()
  love.graphics.setCanvas()

  -- 2) blit canvas -> window: nearest scale fitted to the 3:2 viewport,
  --    padded with black letterbox bars when the window aspect differs
  local w, h = love.graphics.getDimensions()
  local scale = math.min(w / config.VIEW_W, h / config.VIEW_H)
  local ox = (w - config.VIEW_W * scale) * 0.5
  local oy = (h - config.VIEW_H * scale) * 0.5
  love.graphics.clear(0, 0, 0, 1)
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(canvas, ox, oy, 0, scale, scale)
end

-- run-game.sh tells the user Esc quits; honor that in the shell.
function love.keypressed(key)
  for _, m in ipairs(modules) do
    if m.keypressed then m.keypressed(world, key) end
  end
  if key == "escape" then love.event.quit() end
end

-- Input routing for mouse-driven modules (B6: weapons aim + fire). Same
-- pattern as keypressed: thin fan-out, each module keeps its own handler.
function love.mousepressed(x, y, button, istouch, presses)
  for _, m in ipairs(modules) do
    if m.mousepressed then m.mousepressed(world, x, y, button) end
  end
end