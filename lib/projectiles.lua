-- lib/projectiles.lua — projectile motion + death (B6).
-- Ports prototype/combat-weapons projectile update per docs/combat-weapons.md:
-- moving circle sprites advanced by velocity each frame; die on life expiry or
-- on a WALL tile. The tile grid is NOT a hitscan layer — it only blocks
-- movement and kills projectiles (no ray-casting; friendly fire is a B8 hit
-- test). Enemy collision is deliberately absent here: B6 is motion-only, B8
-- adds hit resolution once both movers exist.
--
-- Contract: load/update/draw(world, dt). load() wires world.projectiles; fire
-- (lib/weapons.lua) pushes {x, y, vx, vy, r, life, from, dmg, col} entries.

local projectiles = {}

function projectiles.load(world)
  world.projectiles = {}
end

function projectiles.update(world, dt)
  local list = world.projectiles
  for i = #list, 1, -1 do
    local p = list[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    -- wall death = center entered a non-walkable tile (also kills anything
    -- that somehow left the world); life expiry covers range
    if p.life <= 0 or not world.map.isWalkablePx(p.x, p.y) then
      table.remove(list, i)
    end
  end
end

-- Tinted per weapon (pulse bright, pellets orange), rotated along travel.
-- The 8x8 sprite's bright core + short soft tail read as a tracer at speed.
function projectiles.draw(world)
  local img = world.assets.images.projectile
  world.camera.apply()
  for _, p in ipairs(world.projectiles) do
    local c = p.col
    love.graphics.setColor(c[1], c[2], c[3], 1)
    local s = p.r * 2 / 8 -- r=3 pulse and r=2 pellet both scale from the sprite
    love.graphics.draw(img, p.x, p.y, math.atan2(p.vy, p.vx), s, s, 4, 4)
  end
  world.camera.pop()
end

return projectiles