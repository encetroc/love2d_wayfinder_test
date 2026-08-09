-- lib/enemy.lua — enemy AI: 3 archetypes + spawning (B7).
-- Ports prototypes/enemy-ai (ticket #6, the approved reference) onto the
-- shared-world contract per docs/enemy-ai.md. Awareness is the gate: an enemy
-- is aware only when the player is in the SAME room (room membership from
-- floor.rooms) AND within aggro range; otherwise it de-aggros and idles — no
-- cross-room chasing. chaser seeks, shooter keeps its band and fires #6's
-- 165px/s projectile, tank runs hold -> telegraph -> charge -> recover.
--
-- B7 is motion-only like B6: the shooter's projectile goes into
-- world.projectiles (walls + life expiry kill it; lib/projectiles.lua owns
-- motion) but no hits are resolved yet — enemy HP / damage land in B8
-- (lib/combat.lua). Enemies carry hp/maxhp/flash and dead enemies (hp <= 0)
-- are skipped by update/draw/separation so B8 just wires a damage pass in.
--
-- Contract: load/update/draw(world, dt) + keypressed (debug R respawns from
-- the seed, G toggles always-aggro). load() wires world.enemies and spawns;
-- must load after lib/map.lua (reads world.map.floor) and lib/seeded.lua
-- (spawn draws flow through world.seeded — rule 3).

local enemy = {}

-- Spawn roster, verbatim from the #6 prototype: 3 chaser / 2 shooter / 2 tank,
-- round-robined across the floor's non-spawn rooms (seeded per-room spawn;
-- the spawn room is excluded so it stays enemy-free per #8).
local SPAWN_SLOTS = { "chaser", "chaser", "shooter", "shooter", "tank", "tank", "chaser" }

-- Locked archetype numbers (docs/enemy-ai.md table; prototype is the source).
local DESIGNS = {
  chaser  = { hp = 2, speed = 85, aggro = 150, r = 6 },
  shooter = { hp = 3, speed = 60, aggro = 170, r = 6,
              keep = 95, fire = 150, cd = 1.4, pSpeed = 165 },
  tank    = { hp = 6, speed = 35, aggro = 120, r = 9 },
}

-- Tank charge cycle (prototype numbers): hold keeps 50-95px range for 2.0s,
-- then a 0.55s pulsing telegraph, a 340px/s lunge for 0.4s at the direction
-- locked at windup end, then 0.9s recovery. r=9 is the body radius that
-- blocks 1-tile corridors.
local HOLD_T, WINDUP_T = 2.0, 0.55
local CHARGE_SPEED, CHARGE_T, RECOVER_T = 340, 0.4, 0.9

-- Shooter's projectile, #6 verbatim: 165 px/s, r=2.5, life 3s, motion-only
-- until B8. (1 dmg carried for B8's read; enemies also keep a 0.12s hit-flash
-- field for B8 to drive.)
local PROJ_R, PROJ_LIFE = 2.5, 3.0
local PROJ_DMG = 1 -- enemy->player damage is B8's read; carried for shape
local WARN = { 1.00, 0.85, 0.35 } -- amber "alert" (enemy bullets + tank telegraph)

local alwaysAggro = false -- debug G toggle (prototype parity; dev helper only)

-- --- helpers ---------------------------------------------------------------

local function tileOf(world, px, py)
  return math.floor(px / world.TILE) + 1, math.floor(py / world.TILE) + 1
end

-- The room a pixel point is inside (nil in corridors/walls). The awareness
-- gate compares this against e.room recorded at spawn — same room object or
-- de-aggro (also covers the player standing in a corridor).
local function roomOf(world, px, py)
  local tx, ty = tileOf(world, px, py)
  return world.map.roomAt(tx, ty)
end

local function hitsWall(world, x, y)
  return not world.map.isWalkablePx(x, y)
end

local function tileCenter(world, tx, ty)
  return (tx - 1) * world.TILE + world.TILE / 2, (ty - 1) * world.TILE + world.TILE / 2
end

-- --- spawning --------------------------------------------------------------

local function newEnemy(arch, x, y, room)
  local d = DESIGNS[arch]
  return {
    arch = arch, x = x, y = y, room = room,
    hp = d.hp, maxhp = d.hp, speed = d.speed, aggro = d.aggro, r = d.r,
    keep = d.keep, fire = d.fire, pSpeed = d.pSpeed,
    st = "idle", stT = 0, cdirx = 0, cdiry = 0,
    cd = 0, flash = 0, vx = 0, vy = 0, aware = false,
  }
end

-- Seeded per-room spawn: round-robin SPAWN_SLOTS across the floor's non-spawn
-- rooms, jitter around each room's center tile with retry, room membership
-- recorded at spawn. The retry keeps the spawn INSIDE the assigned room
-- (per-room spawn + the same-room awareness gate): room tiles are all
-- FLOOR by map-gen construction, so in-room implies walkable; the explicit
-- walkable check stays for parity with #6's text. The prototype's huge
-- static rooms made ±2 jitter stay in-room automatically; the generated
-- floor's 2-4 tile rooms need the same guarantee spelled out (a corridor
-- spawn would never aggro, and a tank would brick the corridor). Every draw
-- flows through world.seeded — identical seed => identical spawns (verify:
-- 2 seeds differ; R replays the same layout after map regenerate).
local function spawnEnemies(world)
  local list = {}
  local rooms = {}
  for _, r in ipairs(world.map.floor.rooms) do
    if not r.spawn then rooms[#rooms + 1] = r end
  end
  for i, arch in ipairs(SPAWN_SLOTS) do
    local rc = rooms[(i - 1) % #rooms + 1]
    local cx = rc.rect.x + math.floor(rc.rect.w / 2) -- room center tile
    local cy = rc.rect.y + math.floor(rc.rect.h / 2)
    local tx, ty = cx, cy
    -- seeded jitter + retry: accept only tiles inside the assigned room
    for _ = 1, 8 do
      local jx, jy = world.seeded.int(-2, 2), world.seeded.int(-2, 2)
      local ntx, nty = cx + jx, cy + jy
      if ntx >= rc.rect.x and ntx < rc.rect.x + rc.rect.w
         and nty >= rc.rect.y and nty < rc.rect.y + rc.rect.h
         and world.map.isWalkablePx((ntx - 1) * world.TILE + world.TILE / 2,
                                    (nty - 1) * world.TILE + world.TILE / 2) then
        tx, ty = ntx, nty
        break
      end
    end
    local x, y = tileCenter(world, tx, ty)
    list[#list + 1] = newEnemy(arch, x, y, roomOf(world, x, y))
  end
  return list
end

-- --- awareness -------------------------------------------------------------

local function updateAwareness(world, e)
  local dx, dy = world.player.x - e.x, world.player.y - e.y
  local dist = (dx * dx + dy * dy) ^ 0.5
  local pRoom = roomOf(world, world.player.x, world.player.y)
  local sameRoom = pRoom ~= nil and e.room ~= nil and pRoom == e.room
  e.aware = alwaysAggro or (sameRoom and dist < e.aggro)
  return dx, dy, dist
end

-- --- archetype steering (prototype verbatim, + div-by-zero guard) ----------

local function dirTo(dx, dy, dist)
  if dist > 0.001 then return dx / dist, dy / dist end
  return 0, 0
end

local function steerChaser(e, dx, dy, dist)
  if not e.aware then e.vx, e.vy = 0, 0 return end
  local ux, uy = dirTo(dx, dy, dist)
  e.vx, e.vy = ux * e.speed, uy * e.speed
end

local function steerShooter(world, e, dx, dy, dist, dt)
  if not e.aware then e.vx, e.vy = 0, 0 return end
  local ux, uy = dirTo(dx, dy, dist)
  -- keep-band: back off inside keep, approach past fire, hold + fire between
  if dist < e.keep then
    e.vx, e.vy = -ux * e.speed, -uy * e.speed
  elseif dist > e.fire then
    e.vx, e.vy = ux * e.speed, uy * e.speed
  else
    e.vx, e.vy = 0, 0
  end
  e.cd = e.cd - dt
  if e.cd <= 0 and dist <= e.fire + 40 then
    local list = world.projectiles
    list[#list + 1] = {
      x = e.x + ux * 10, y = e.y + uy * 10,
      vx = ux * e.pSpeed, vy = uy * e.pSpeed,
      r = PROJ_R, life = PROJ_LIFE, from = "enemy", dmg = PROJ_DMG, col = WARN,
    }
    e.cd = 1.4
  end
end

local function steerTank(e, dx, dy, dist, dt)
  if not e.aware then
    e.vx, e.vy, e.st, e.stT = 0, 0, "idle", 0
    return
  end
  local ux, uy = dirTo(dx, dy, dist)
  if e.st == "hold" or e.st == "windup" then e.cdirx, e.cdiry = ux, uy end
  if e.st == "idle" then e.st, e.stT = "hold", 0 end

  if e.st == "hold" then
    e.stT = e.stT + dt
    -- slow nudge to keep mid-range, else hold ground (blocks the corridor)
    if dist > 95 then
      e.vx, e.vy = ux * e.speed * 0.5, uy * e.speed * 0.5
    elseif dist < 50 then
      e.vx, e.vy = -ux * e.speed * 0.4, -uy * e.speed * 0.4
    else
      e.vx, e.vy = 0, 0
    end
    if e.stT >= HOLD_T then e.st, e.stT = "windup", 0 end -- charge timer
  elseif e.st == "windup" then
    e.stT = e.stT + dt
    e.vx, e.vy = 0, 0
    if e.stT >= WINDUP_T then -- telegraph done -> lunge; lock direction NOW
      e.st, e.stT = "charge", 0
      e.cdirx, e.cdiry = ux, uy
    end
  elseif e.st == "charge" then
    e.stT = e.stT + dt
    e.vx, e.vy = e.cdirx * CHARGE_SPEED, e.cdiry * CHARGE_SPEED
    if e.stT >= CHARGE_T then e.st, e.stT = "recover", 0 end
  else -- recover
    e.stT = e.stT + dt
    e.vx, e.vy = 0, 0
    if e.stT >= RECOVER_T then e.st, e.stT = "hold", 0 end
  end
end

-- --- per-enemy update ------------------------------------------------------

local function updateEnemy(world, e, dt)
  local dx, dy, dist = updateAwareness(world, e)
  e.flash = math.max(0, e.flash - dt)
  if e.arch == "chaser" then
    steerChaser(e, dx, dy, dist)
  elseif e.arch == "shooter" then
    steerShooter(world, e, dx, dy, dist, dt)
  else
    steerTank(e, dx, dy, dist, dt)
  end

  -- separation: per-frame push apart when r1+r2+4 overlap (stops stacking;
  -- lets tanks body-block corridors). Applied as a velocity bias, verbatim.
  local fx, fy = 0, 0
  for _, o in ipairs(world.enemies) do
    if o ~= e and o.hp > 0 then
      local dx, dy = e.x - o.x, e.y - o.y
      local d2 = dx * dx + dy * dy
      local min = e.r + o.r + 4
      if d2 > 0.0001 and d2 < min * min then
        local d = d2 ^ 0.5
        local push = (min - d) / min
        fx = fx + (dx / d) * push
        fy = fy + (dy / d) * push
      end
    end
  end
  local fLen = (fx * fx + fy * fy) ^ 0.5
  if fLen > 0.001 then
    e.vx = e.vx + (fx / fLen) * 30
    e.vy = e.vy + (fy / fLen) * 30
  end

  -- move with wall-slide: axis-separated against the tile grid (blocked axis
  -- stops, the free axis keeps going — same shape as lib/player.lua)
  local nx, ny = e.x + e.vx * dt, e.y + e.vy * dt
  if not (hitsWall(world, nx + e.r, e.y) or hitsWall(world, nx - e.r, e.y)) then
    e.x = nx
  end
  if not (hitsWall(world, e.x, ny + e.r) or hitsWall(world, e.x, ny - e.r)) then
    e.y = ny
  end
end

-- --- module contract -------------------------------------------------------

function enemy.load(world)
  world.enemies = {}
  enemy.spawn(world)
end

-- (Re)spawn all enemies from world.seeded (exposed for R replay + tests).
function enemy.spawn(world)
  world.enemies = spawnEnemies(world)
end

function enemy.update(world, dt)
  for _, e in ipairs(world.enemies) do
    if e.hp > 0 then updateEnemy(world, e, dt) end
  end
end

function enemy.draw(world)
  if not world.camera or not world.player then return end
  local imgs = world.assets.images
  local player = world.player
  world.camera.apply() -- world-space content below; camera.pop() at the end

  for _, e in ipairs(world.enemies) do
    if e.hp > 0 then
      -- emissive under-glow, Antecrypt entity language (the player gets one too)
      world.assets.drawGlow(imgs.glow, e.x - 8, e.y - 8, 1.2)

      local img = imgs.enemy_chaser
      local rot = 0
      if e.arch == "chaser" then
        -- triangle sprite points up by default; rotate to aim at the player
        rot = math.atan2(player.y - e.y, player.x - e.x) + math.pi / 2
      elseif e.arch == "shooter" then
        img = imgs.enemy_shooter
      else
        img = imgs.enemy_tank
      end
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(img, e.x - 8, e.y - 8, rot)

      -- tank telegraphs: pulsing expanding warn ring (windup), white-hot core
      -- flash (charge), locked direction line (windup + charge)
      if e.arch == "tank" then
        if e.st == "windup" then
          love.graphics.setColor(WARN[1], WARN[2], WARN[3],
            0.5 + 0.5 * math.sin(e.stT * 30))
          love.graphics.circle("line", e.x, e.y, e.r + 6 + e.stT * 60)
        elseif e.st == "charge" then
          love.graphics.setColor(1, 1, 1, 0.6)
          love.graphics.circle("fill", e.x, e.y, e.r * 1.15)
          love.graphics.setColor(1, 1, 1, 1)
          love.graphics.draw(img, e.x - 8, e.y - 8, rot)
        end
        if e.st == "windup" or e.st == "charge" then
          love.graphics.setColor(WARN[1], WARN[2], WARN[3], 0.5)
          love.graphics.line(e.x + e.cdirx * e.r, e.y + e.cdiry * e.r,
                             e.x + e.cdirx * (e.r + 16), e.y + e.cdiry * (e.r + 16))
        end
      end

      -- hit flash (white core wash; B8 drives flash on damage)
      if e.flash > 0 then
        love.graphics.setColor(1, 1, 1, math.min(1, e.flash * 6))
        love.graphics.circle("fill", e.x, e.y, e.r)
      end

      -- hp pips above the body (bright green filled / dark empty)
      for i = 1, e.maxhp do
        local px = e.x - (e.maxhp - 1) * 3 + (i - 1) * 6
        if i <= e.hp then
          love.graphics.setColor(0.45, 1.00, 0.58, 0.9)
        else
          love.graphics.setColor(0.10, 0.25, 0.16, 0.8)
        end
        love.graphics.rectangle("fill", px - 2, e.y - e.r - 9, 4, 3)
      end

      -- awareness ring: dev readout (same spirit as map's debug room tags)
      if world.debug and e.aware then
        love.graphics.setColor(1, 1, 1, 0.5)
        love.graphics.circle("line", e.x, e.y, e.r + 3)
      end
    end
  end
  world.camera.pop()
end

-- Debug helpers only (never shipped UX, per backlog scope notes):
--   R  — respawn enemies from the current seed (map.keypressed runs first and
--        already re-seeded + regenerated the floor, so this replays the exact
--        seed layout). B10 later takes R over for full-run replay.
--   G  — toggle always-aggro (prototype parity; makes band/charge behavior
--        verifiable without walking into range).
function enemy.keypressed(world, key)
  if not world.debug then return end
  if key == "r" then
    enemy.spawn(world)
  elseif key == "g" then
    alwaysAggro = not alwaysAggro
  end
end

return enemy