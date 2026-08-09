-- lib/camera.lua — centered-follow viewport camera (B5).
-- Tracks the player's center each frame, clamps to the world so nothing past
-- the 640x480 edge is ever shown, and eases with light smoothing instead of
-- teleporting. No aim-bias in v1 (docs/viewport-camera.md); screen shake is
-- B12 polish. Camera scroll range: x in [0, 640-480=160], y in [0, 480-360=120].
--
-- Contract: load/update/draw(world, dt). load() wires world.camera with the
-- current view x/y plus an apply() transform for modules that draw world
-- space (map, player, later enemies). Debug readouts/HUD draw in screen space
-- and must NOT call apply().

local camera = {}

local SMOOTH = 8 -- lerp rate: higher = snappier

-- target = player center - half viewport, clamped to world bounds
local function desired(world)
  local p = world.player
  local tx = p.x - world.VIEW_W / 2
  local ty = p.y - world.VIEW_H / 2
  tx = math.max(0, math.min(world.WORLD_W - world.VIEW_W, tx))
  ty = math.max(0, math.min(world.WORLD_H - world.VIEW_H, ty))
  return tx, ty
end

function camera.load(world)
  camera.x, camera.y = desired(world)
  camera.apply = function()
    love.graphics.push()
    love.graphics.translate(math.floor(camera.x), math.floor(camera.y))
    -- floor so 1:1 tiles stay pixel-aligned during smoothing; still clamped
  end
  camera.pop = love.graphics.pop
  world.camera = camera
end

function camera.update(world, dt)
  local tx, ty = desired(world)
  local k = 1 - math.exp(-SMOOTH * dt)
  camera.x = camera.x + (tx - camera.x) * k
  camera.y = camera.y + (ty - camera.y) * k
  -- clamp AFTER smoothing: never show past the world edge
  camera.x = math.max(0, math.min(world.WORLD_W - world.VIEW_W, camera.x))
  camera.y = math.max(0, math.min(world.WORLD_H - world.VIEW_H, camera.y))
end

function camera.draw()
end

return camera