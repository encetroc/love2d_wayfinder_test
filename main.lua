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
--   B7  require("lib.enemy")
--   B8  require("lib.combat")
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

-- Temporary boot readout; proves the canvas pipeline renders and shows the
-- contract state. lib/seeded adds the RNG panel below it; B12's real HUD
-- replaces all of it.
local function drawBootReadout()
  local w, h = love.graphics.getDimensions()
  local scale = math.min(w / config.VIEW_W, h / config.VIEW_H)

  -- canvas boundary, so the letterbox bars vs. canvas is visible on resize
  love.graphics.setColor(1, 1, 1, 0.35)
  love.graphics.rectangle("line", 0.5, 0.5, config.VIEW_W - 1, config.VIEW_H - 1)

  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.print(config.TITLE .. " — B1 shell", 8, 8)
  love.graphics.print(
    string.format("canvas %dx%d -> window %dx%d (x%.2f)",
      config.VIEW_W, config.VIEW_H, w, h, scale),
    8, 24)
  love.graphics.print("seed " .. world.seed, 8, 40)
  love.graphics.print(
    string.format("player (%.0f,%.0f) cam (%.0f,%.0f)",
      world.player.x, world.player.y, world.camera.x, world.camera.y),
    8, 56)
  love.graphics.print("modules registered: " .. #modules .. " / 12 planned", 8, 64)
  -- B6 dev readout: current weapon / reserve ammo / live projectile count
  -- (top-right; the B12 HUD replaces this whole block)
  if world.weapons and world.player.weapon then
    local d = world.weapons.DEFS[world.player.weapon]
    love.graphics.setColor(1, 0.9, 0.5, 1)
    love.graphics.print(string.format("%s ammo %d/%d  proj %d", d.name,
      world.player.ammo[world.player.weapon], d.max, #(world.projectiles or {})),
      320, 8)
    love.graphics.setColor(1, 1, 1, 1)
  end
end

function love.load()
  love.graphics.setDefaultFilter("nearest", "nearest") -- pixel-crisp upscale
  canvas = love.graphics.newCanvas(config.VIEW_W, config.VIEW_H)
  buildWorld()
  for _, m in ipairs(modules) do
    if m.load then m.load(world) end
  end
end

function love.update(dt)
  frameDt = dt
  for _, m in ipairs(modules) do
    if m.update then m.update(world, dt) end
  end
end

function love.draw()
  -- 1) render the world into the base-res canvas
  love.graphics.setCanvas(canvas)
  love.graphics.clear(0.06, 0.07, 0.10, 1)
  for _, m in ipairs(modules) do
    if m.draw then m.draw(world, frameDt) end
  end
  drawBootReadout()
  love.graphics.setCanvas()

  -- 2) blit canvas -> window: nearest scale fitted to the 3:2 viewport,
  --    padded with letterbox bars when the window aspect differs
  local w, h = love.graphics.getDimensions()
  local scale = math.min(w / config.VIEW_W, h / config.VIEW_H)
  local ox = (w - config.VIEW_W * scale) * 0.5
  local oy = (h - config.VIEW_H * scale) * 0.5
  love.graphics.clear(0.02, 0.02, 0.04, 1) -- letterbox bars
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