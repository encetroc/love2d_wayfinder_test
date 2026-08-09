-- lib/player.lua — player movement (B5) + weapon switching (B6).
-- Continuous-pixel movement on the tile grid with per-axis wall collision
-- (this IS the wall-slide: blocked axis stops, free axis keeps moving).
-- Position is the player center in world px; a small circle hitbox.
-- Health/damage/i-frames land in B8; ammo + firing live in lib/weapons.lua
-- (B6) with the weapon swap keyhandler here (docs/combat-weapons.md).
--
-- Contract: load/update/draw(world, dt). Wired as world.player.

local RADIUS = 5 -- circle hitbox radius (px)

local player = {
  RADIUS = RADIUS,
}

local function spawnPoint(world)
  local s = world.map.floor.spawn
  return (s.tx - 0.5) * world.TILE, (s.ty - 0.5) * world.TILE -- tile center
end

-- Would the hitbox circle at (cx, cy) overlap a non-walkable tile? Corners of
-- the bounding box suffice at TILE >> RADIUS with sub-tile per-frame steps.
local function collides(world, cx, cy)
  local r = RADIUS
  local corners = {
    { cx - r, cy - r }, { cx + r, cy - r },
    { cx - r, cy + r }, { cx + r, cy + r },
  }
  for _, c in ipairs(corners) do
    if not world.map.isWalkablePx(c[1], c[2]) then return true end
  end
  return false
end

-- --- module contract ------------------------------------------------------

function player.load(world)
  world.player = player
  player.x, player.y = spawnPoint(world)
end

-- Move by (dx, dy) world px, resolving each axis independently (wall-slide).
-- Exposed for tests/smoke; update() feeds it from input.
function player.tryMove(world, dx, dy)
  local nx = player.x + dx
  if not collides(world, nx, player.y) then player.x = nx end
  local ny = player.y + dy
  if not collides(world, player.x, ny) then player.y = ny end
  -- clamp to the world bounds (belt+brackets; walls normally do this)
  player.x = math.max(RADIUS, math.min(world.WORLD_W - RADIUS, player.x))
  player.y = math.max(RADIUS, math.min(world.WORLD_H - RADIUS, player.y))
end

-- WASD + arrow keys; 130 px/s (docs/combat-weapons.md), diagonal normalized.
function player.update(world, dt)
  -- B8: HP 0 = dead; the corpse doesn't walk. combat.lua owns hp; B10's DEAD
  -- state takes over the run from here (permadeath overlay, restart).
  if player.hp and player.hp <= 0 then return end
  local dx, dy = 0, 0
  if love.keyboard.isDown("a", "left") then dx = dx - 1 end
  if love.keyboard.isDown("d", "right") then dx = dx + 1 end
  if love.keyboard.isDown("w", "up") then dy = dy - 1 end
  if love.keyboard.isDown("s", "down") then dy = dy + 1 end
  local len = (dx * dx + dy * dy) ^ 0.5
  if len > 0 then
    dx, dy = dx / len, dy / len
  end
  player.tryMove(world, dx * 130 * dt, dy * 130 * dt)
end

function player.draw(world)
  -- B6: drawn inside camera.apply like the map — B5 shipped the sprite at raw
  -- world coords, so once the camera left (0,0) the player slid off-screen
  world.camera.apply()
  -- B8: i-frames blink — skip the sprite every other 0.05s tick while
  -- invulnerable (classic 0.5s invuln cue, prototype parity).
  local blinking = player.iframes and player.iframes > 0
    and math.floor(player.iframes * 20) % 2 == 0
  if not blinking then
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(world.assets.images.player, player.x - 8, player.y - 8)
    world.assets.drawGlow(world.assets.images.glow, player.x - 8, player.y - 8, 1.3)
  end
  -- B8: 0.25s hurt flash — red wash over the body (damage accent family per
  -- B6.1; reads against the green sprite as "just took a hit").
  if player.flash and player.flash > 0 then
    love.graphics.setColor(1, 0.25, 0.25, math.min(1, player.flash * 4) * 0.55)
    love.graphics.circle("fill", player.x, player.y, player.RADIUS + 2)
  end
  world.camera.pop()
end

-- Weapon swap: 1/2 (keys are free again — B6 remapped the B3 debug sfx
-- audition off the number row since 1/2 are now gameplay). No cd reset on
-- swap; switching is instant, firing respects each weapon's own cooldown.
function player.keypressed(world, key)
  if not world.weapons then return end
  local idx = (key == "1") and 1 or (key == "2") and 2
  if not idx then return end
  world.player.weapon = world.weapons.ORDER[idx]
end

return player