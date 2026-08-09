-- ============================================================================
-- PROTOTYPE: Combat & weapon model — 2 weapons / ammo / projectiles / damage  v1
-- Throwaway code answering: "do these two weapon identities + numbers feel right?"
-- Ticket: wayfinder #11. Run with:  love prototypes/combat-weapons
--
-- Inherits LOCKED inputs:
--   #2 floor model   : TILE=16, world 640x480 (40x30 tiles), room list + wall grid
--   #3 viewport      : base res 480x360, x2 -> 960x720 window, centered follow
--                      camera clamped to world, light smoothing
--   #6 enemy AI      : chaser 2hp/85spd/aggro150; shooter 3hp/60spd (keep 95,
--                      fire 150, cd 1.4s, proj 165px/s r2.5); tank 6hp charger
--                      (hold 50-95, 0.55s windup, 340 charge 0.4s, 0.9s recover,
--                      r9); separation + wall-slide; hit-flash 0.12s
--
-- THIS TICKET decides (proposal — playtest to validate):
--   WEAPON 1 "PULSE"   : fast single-shot pistol. cd 0.22s, 1 dmg, proj 300px/s
--                        r3, life 0.9, accurate. ammo 30/60.
--   WEAPON 2 "SCATTER" : heavy shotgun. cd 0.55s, 5 pellets x 1 dmg in a ±9°
--                        fan (jitter), proj 260px/s r2, life 0.35 (~91px,
--                        close-range burst). ammo 8/16.
--   Player: 130 px/s, 4 HP, 0.5s i-frames after a hit, red hurt flash.
--   Enemy->player dmg: chaser contact 1, shooter projectile 1, tank charge 2.
--   Hit detection: circle-overlap entity bounds (proj-vs-enemy, proj-vs-player,
--   contact-vs-player); the grid only blocks movement and kills projectiles
--   (WALL tile) — no hitscan. HP in integer hits.
-- Keys: WASD/arrows = move, mouse = aim, click = fire, 1/2 = switch weapon,
--       R = regenerate same seed, G = always-aggro toggle, F = refill ammo.
-- ============================================================================

local TILE      = 16
local COLS      = 40
local ROWS      = 30
local WORLD_W, WORLD_H = COLS * TILE, ROWS * TILE    -- 640 x 480
local VIEW_W, VIEW_H   = 480, 360                    -- #3 base res (3:2)
local SCALE    = 2                                   -- window 960 x 720
local SEED     = 20240807
local WALL, FLOOR = "WALL", "FLOOR"

-- ---------------------------------------------------------------- palette
local COL = {
  floor    = {0.06, 0.05, 0.10},
  wall     = {0.12, 0.11, 0.16},
  wallEdge = {0.35, 0.90, 1.00},
  player   = {0.20, 1.00, 1.00},
  chaser   = {1.00, 0.20, 1.00},
  shooter  = {1.00, 0.55, 0.10},
  tank     = {1.00, 0.25, 0.25},
  warn     = {1.00, 0.95, 0.30},
  shot     = {1.00, 1.00, 0.40},   -- pulse projectile
  proj     = {1.00, 0.80, 0.20},   -- enemy projectile
  pellet   = {1.00, 0.60, 0.15},   -- scatter pellet
  hp       = {0.40, 1.00, 0.40},
  crate    = {0.45, 0.85, 1.00},
  crate2   = {1.00, 0.70, 0.25},
}

-- ---------------------------------------------------------------- map gen
local grid, roomGrid = {}, {}

local function rect(x0, y0, x1, y1, kind, id)
  for ty = y0, y1 do
    for tx = x0, x1 do
      grid[ty][tx] = kind
      if kind == FLOOR and id then roomGrid[ty][tx] = id end
    end
  end
end

local function buildFloor()
  grid, roomGrid = {}, {}
  for ty = 1, ROWS do grid[ty] = {} roomGrid[ty] = {} end
  rect(2, 2, 13, 9, FLOOR, 1)              -- room 1 (start, left)
  rect(20, 2, 37, 11, FLOOR, 2)            -- room 2 (top-right)
  rect(4, 15, 15, 27, FLOOR, 3)            -- room 3 (bottom-left)
  rect(20, 15, 37, 27, FLOOR, 4)           -- room 4 (bottom-right)
  rect(14, 5, 19, 5, FLOOR, 1)             -- corridor 1->2
  rect(20, 5, 20, 5, FLOOR, 1)
  rect(5, 10, 5, 14, FLOOR, 1)             -- corridor 1->3
  rect(5, 15, 5, 15, FLOOR, 1)
  rect(24, 12, 24, 14, FLOOR, 2)           -- corridor 2->4
  rect(24, 15, 24, 15, FLOOR, 2)
  rect(16, 21, 19, 21, FLOOR, 3)           -- corridor 3->4
  rect(20, 21, 20, 21, FLOOR, 3)
  -- cover pillars
  for _, p in ipairs({ {6,4},{10,7},{23,4},{33,6},{27,9},{7,20},{12,24},{33,20},{28,25},{22,23} }) do
    grid[p[2]][p[1]] = WALL
  end
end

local function blocked(px, py)
  local tx, ty = math.floor(px / TILE) + 1, math.floor(py / TILE) + 1
  if tx < 1 or tx > COLS or ty < 1 or ty > ROWS then return true end
  return grid[ty][tx] == WALL
end

local function roomAt(px, py)
  local tx, ty = math.floor(px / TILE) + 1, math.floor(py / TILE) + 1
  if tx < 1 or tx > COLS or ty < 1 or ty > ROWS then return nil end
  return roomGrid[ty] and roomGrid[ty][tx]
end

-- ---------------------------------------------------------------- state
local player, enemies, projectiles, crates
local alwaysAggro = false
local kills = 0
local camX, camY = 0, 0
local deathT = 0

-- ---------------------------------------------------------------- weapons
local WEAPONS = {
  pulse = {
    name = "PULSE", cd = 0.22, dmg = 1, speed = 300, pr = 3, life = 0.9,
    pellets = 1, spread = 0.00, col = COL.shot, ammo = 30, max = 60,
  },
  scatter = {
    name = "SCATTER", cd = 0.55, dmg = 1, speed = 260, pr = 2, life = 0.35,
    pellets = 5, spread = 0.16, col = COL.pellet, ammo = 8, max = 16,
  },
}
local WEAPON_ORDER = { "pulse", "scatter" }

-- ---------------------------------------------------------------- enemies (#6 locked)
-- room 1 = safe start (weapon feel first); archetypes live in rooms 2-4
local SPAWN_SLOTS = {
  { "shooter", 2 }, { "shooter", 2 }, { "chaser", 2 },
  { "chaser",  3 }, { "chaser",  3 }, { "tank",    3 },
  { "tank",    4 }, { "shooter", 4 }, { "chaser", 4 },
}
local ROOM_CENTERS = { {7, 5}, {28, 6}, {9, 20}, {28, 21} }

local DESIGNS = {
  chaser  = { hp = 2, speed = 85,  aggro = 150 },
  shooter = { hp = 3, speed = 60,  aggro = 170, keep = 95, fire = 150, cd = 1.4, pSpeed = 165 },
  tank    = { hp = 6, speed = 35,  aggro = 120, chargeDir = nil },
}

local function newEnemy(arch, x, y, room)
  local d = DESIGNS[arch]
  return {
    arch = arch, x = x, y = y, room = room,
    hp = d.hp, maxhp = d.hp, speed = d.speed, aggro = d.aggro,
    r = (arch == "tank") and 9 or 6,
    keep = d.keep, fire = d.fire, pSpeed = d.pSpeed,
    st = "idle", stT = 0, cdirx = 0, cdiry = 0,
    cd = 0, flash = 0, vx = 0, vy = 0, aware = false,
  }
end

local function tileCenter(tx, ty) return (tx - 1) * TILE + 8, (ty - 1) * TILE + 8 end

local function spawnEnemies()
  enemies = {}
  love.math.setRandomSeed(SEED)
  for _, slot in ipairs(SPAWN_SLOTS) do
    local arch, roomId = slot[1], slot[2]
    local rc = ROOM_CENTERS[roomId]
    local tx, ty = rc[1], rc[2]
    for _ = 1, 8 do
      local jx, jy = love.math.random(-2, 2), love.math.random(-2, 2)
      local px, py = tileCenter(rc[1] + jx, rc[2] + jy)
      if not blocked(px, py) then tx, ty = rc[1] + jx, rc[2] + jy break end
    end
    local px, py = tileCenter(tx, ty)
    table.insert(enemies, newEnemy(arch, px, py, roomAt(px, py)))
  end
end

-- ---------------------------------------------------------------- ammo crates (prototype stand-in; real pickups = #4)
local function spawnCrates()
  crates = {
    { kind = "pulse",   x = 3 * TILE + 8,  y = 8 * TILE + 8 },
    { kind = "pulse",   x = 36 * TILE + 8, y = 10 * TILE + 8 },
    { kind = "scatter", x = 21 * TILE + 8, y = 3 * TILE + 8 },
    { kind = "pulse",   x = 5 * TILE + 8,  y = 26 * TILE + 8 },
    { kind = "scatter", x = 35 * TILE + 8, y = 25 * TILE + 8 },
  }
end

-- ---------------------------------------------------------------- reset
local function reset()
  buildFloor()
  player = {
    x = 7 * TILE + 8, y = 5 * TILE + 8, r = 6, speed = 130,
    hp = 4, maxhp = 4, iframes = 0, flash = 0, weapon = "pulse",
    ammo = { pulse = 30, scatter = 8 }, cd = 0, muzzle = 0, aim = 0,
  }
  projectiles = {}
  spawnEnemies()
  spawnCrates()
  kills = 0
  deathT = 0
  camX, camY = player.x - VIEW_W / 2, player.y - VIEW_H / 2
end

-- ---------------------------------------------------------------- player update
local function updatePlayer(dt)
  if player.hp <= 0 then
    deathT = deathT + dt
    return
  end
  local kx, ky = 0, 0
  if love.keyboard.isDown("w", "up")    then ky = ky - 1 end
  if love.keyboard.isDown("s", "down")  then ky = ky + 1 end
  if love.keyboard.isDown("a", "left")  then kx = kx - 1 end
  if love.keyboard.isDown("d", "right") then kx = kx + 1 end
  local len = math.sqrt(kx * kx + ky * ky)
  if len > 0 then kx, ky = kx / len, ky / len end
  local nx = player.x + kx * player.speed * dt
  local ny = player.y + ky * player.speed * dt
  if not (blocked(nx + player.r, player.y) or blocked(nx - player.r, player.y)) then player.x = nx end
  if not (blocked(player.x, ny + player.r) or blocked(player.x, ny - player.r)) then player.y = ny end

  player.iframes = math.max(0, player.iframes - dt)
  player.flash   = math.max(0, player.flash - dt)
  player.muzzle  = math.max(0, player.muzzle - dt)
  player.cd      = math.max(0, player.cd - dt)
end

-- ---------------------------------------------------------------- firing
local function fireWeapon(ang)
  local w = WEAPONS[player.weapon]
  if player.cd > 0 then return end
  if player.ammo[player.weapon] <= 0 then return end
  player.ammo[player.weapon] = player.ammo[player.weapon] - 1
  player.cd = w.cd
  player.muzzle = 0.05
  player.aim = ang
  for i = 1, w.pellets do
    local a = ang + (i - (w.pellets + 1) / 2) * ((w.pellets > 1) and (w.spread * 2 / (w.pellets - 1)) or 0)
               + (love.math.random() - 0.5) * 0.08
    local sx, sy = player.x + math.cos(a) * (player.r + 4), player.y + math.sin(a) * (player.r + 4)
    table.insert(projectiles, {
      x = sx, y = sy, vx = math.cos(a) * w.speed, vy = math.sin(a) * w.speed,
      r = w.pr, life = w.life, from = "player", dmg = w.dmg, col = w.col,
    })
  end
end

-- ---------------------------------------------------------------- enemy update (ported verbatim from #6 framework)
local function separation(e, forces)
  for _, o in ipairs(enemies) do
    if o ~= e and o.hp > 0 then
      local dx, dy = e.x - o.x, e.y - o.y
      local d2 = dx * dx + dy * dy
      local min = e.r + o.r + 4
      if d2 > 0.0001 and d2 < min * min then
        local d = math.sqrt(d2)
        local push = (min - d) / min
        forces.x = forces.x + (dx / d) * push
        forces.y = forces.y + (dy / d) * push
      end
    end
  end
end

local function updateAwareness(e, pRoom)
  local dx, dy = player.x - e.x, player.y - e.y
  local dist = math.sqrt(dx * dx + dy * dy)
  local sameRoom = pRoom and e.room and pRoom == e.room
  e.aware = (alwaysAggro or (sameRoom and dist < e.aggro))
  return dx, dy, dist
end

local function steerChaser(e, dx, dy, dist)
  if not e.aware then e.vx, e.vy = 0, 0 return end
  local ux, uy = dx / dist, dy / dist
  e.vx, e.vy = ux * e.speed, uy * e.speed
end

local function steerShooter(e, dx, dy, dist, dt)
  if not e.aware then e.vx, e.vy = 0, 0 return end
  local ux, uy = dx / dist, dy / dist
  if dist < e.keep then
    e.vx, e.vy = -ux * e.speed, -uy * e.speed
  elseif dist > e.fire then
    e.vx, e.vy = ux * e.speed, uy * e.speed
  else
    e.vx, e.vy = 0, 0
  end
  e.cd = e.cd - dt
  if e.cd <= 0 and dist <= e.fire + 40 then
    table.insert(projectiles, { x = e.x + ux * 10, y = e.y + uy * 10,
                                vx = ux * e.pSpeed, vy = uy * e.pSpeed,
                                r = 2.5, from = "enemy", dmg = 1, col = COL.proj, life = 3 })
    e.cd = 1.4
  end
end

local function steerTank(e, dx, dy, dist, dt)
  if not e.aware then
    e.vx, e.vy, e.st, e.stT = 0, 0, "idle", 0
    return
  end
  local ux, uy = dx / dist, dy / dist
  if e.st == "hold" or e.st == "windup" then e.cdirx, e.cdiry = ux, uy end
  if e.st == "idle" then e.st, e.stT = "hold", 0 end

  if e.st == "hold" then
    e.stT = e.stT + dt
    if dist > 95 then e.vx, e.vy = ux * e.speed * 0.5, uy * e.speed * 0.5
    elseif dist < 50 then e.vx, e.vy = -ux * e.speed * 0.4, -uy * e.speed * 0.4
    else e.vx, e.vy = 0, 0 end
    if e.stT >= 2.0 then e.st, e.stT = "windup", 0 end
  elseif e.st == "windup" then
    e.stT = e.stT + dt
    e.vx, e.vy = 0, 0
    if e.stT >= 0.55 then
      e.st, e.stT = "charge", 0
      e.cdirx, e.cdiry = ux, uy
    end
  elseif e.st == "charge" then
    e.stT = e.stT + dt
    e.vx, e.vy = e.cdirx * 340, e.cdiry * 340
    if e.stT >= 0.4 then e.st, e.stT = "recover", 0 end
  else -- recover
    e.stT = e.stT + dt
    e.vx, e.vy = 0, 0
    if e.stT >= 0.9 then e.st, e.stT = "hold", 0 end
  end
end

local function updateEnemy(e, dt)
  local dx, dy, dist = updateAwareness(e, roomAt(player.x, player.y))
  e.flash = math.max(0, e.flash - dt)
  if e.arch == "chaser" then
    steerChaser(e, dx, dy, dist)
  elseif e.arch == "shooter" then
    steerShooter(e, dx, dy, dist, dt)
  else
    steerTank(e, dx, dy, dist, dt)
  end

  local forces = { x = 0, y = 0 }
  separation(e, forces)
  local fLen = math.sqrt(forces.x ^ 2 + forces.y ^ 2)
  if fLen > 0.001 then
    e.vx = e.vx + (forces.x / fLen) * 30
    e.vy = e.vy + (forces.y / fLen) * 30
  end

  local nx, ny = e.x + e.vx * dt, e.y + e.vy * dt
  if not (blocked(nx + e.r, e.y) or blocked(nx - e.r, e.y)) then e.x = nx end
  if not (blocked(e.x, ny + e.r) or blocked(e.x, ny - e.r)) then e.y = ny end
end

-- ---------------------------------------------------------------- damage flow
local function hurtPlayer(dmg)
  if player.hp <= 0 or player.iframes > 0 then return end
  player.hp = player.hp - dmg
  player.iframes = 0.5
  player.flash = 0.25
  if player.hp <= 0 then
    player.hp = 0
    deathT = 0
  end
end

local function updateProjectiles(dt)
  for i = #projectiles, 1, -1 do
    local p = projectiles[i]
    p.x = p.x + p.vx * dt
    p.y = p.y + p.vy * dt
    p.life = p.life - dt
    local hit = false
    if p.from == "player" then
      for _, e in ipairs(enemies) do
        if e.hp > 0 then
          local d2 = (p.x - e.x) ^ 2 + (p.y - e.y) ^ 2
          if d2 < (e.r + p.r) ^ 2 then
            e.hp = e.hp - p.dmg
            e.flash = 0.12
            if e.hp <= 0 then kills = kills + 1 end
            hit = true
            break
          end
        end
      end
    else
      local d2 = (p.x - player.x) ^ 2 + (p.y - player.y) ^ 2
      if d2 < (player.r + p.r) ^ 2 then
        hurtPlayer(p.dmg)
        hit = true
      end
    end
    if hit or p.life <= 0 or blocked(p.x, p.y) then table.remove(projectiles, i) end
  end
end

-- enemy contact damage (chaser = touch, tank = charge only)
local function updateContactDamage()
  if player.hp <= 0 or player.iframes > 0 then return end
  for _, e in ipairs(enemies) do
    if e.hp > 0 and e.aware then
      local d2 = (e.x - player.x) ^ 2 + (e.y - player.y) ^ 2
      local rr = e.r + player.r
      if d2 < rr * rr then
        if e.arch == "tank" then
          if e.st == "charge" then hurtPlayer(2) end
        else
          hurtPlayer(1)
        end
      end
    end
  end
end

local function updateCrates(dt)
  if player.hp <= 0 then return end
  for _, c in ipairs(crates) do
    if not c.taken then
      local d2 = (c.x - player.x) ^ 2 + (c.y - player.y) ^ 2
      if d2 < (player.r + 8) ^ 2 then
        c.taken = true
        local w = WEAPONS[c.kind]
        player.ammo[c.kind] = math.min(w.max, player.ammo[c.kind] + (c.kind == "pulse" and 6 or 2))
      end
    end
  end
end

-- ---------------------------------------------------------------- camera (#3)
local function updateCamera(dt)
  local tx = math.max(0, math.min(WORLD_W - VIEW_W, player.x - VIEW_W / 2))
  local ty = math.max(0, math.min(WORLD_H - VIEW_H, player.y - VIEW_H / 2))
  local k = 1 - math.exp(-dt * 8)
  camX = camX + (tx - camX) * k
  camY = camY + (ty - camY) * k
end

function love.update(dt)
  updatePlayer(dt)
  for _, e in ipairs(enemies) do
    if e.hp > 0 then updateEnemy(e, dt) end
  end
  updateProjectiles(dt)
  updateContactDamage()
  updateCrates(dt)
  updateCamera(dt)
end

-- ---------------------------------------------------------------- input
function love.keypressed(key)
  if key == "r" then reset() end
  if key == "g" then alwaysAggro = not alwaysAggro end
  if key == "f" then
    player.ammo.pulse = WEAPONS.pulse.max
    player.ammo.scatter = WEAPONS.scatter.max
  end
  if key == "1" then player.weapon = "pulse" end
  if key == "2" then player.weapon = "scatter" end
end

function love.mousepressed(mx, my, button)
  if button ~= 1 then return end
  if player.hp <= 0 then return end
  local wx = mx / SCALE + camX
  local wy = my / SCALE + camY
  local ang = math.atan2(wy - player.y, wx - player.x)
  fireWeapon(ang)
  player.aim = ang
end

-- ---------------------------------------------------------------- draw
local function glow(c, x, y, r)
  love.graphics.setBlendMode("add")
  love.graphics.setColor(c[1], c[2], c[3], 0.25)
  love.graphics.circle("fill", x, y, r * 1.9)
  love.graphics.setBlendMode("alpha")
end

local function drawEnemy(e)
  local c = COL[e.arch]
  glow(c, e.x, e.y, e.r)
  love.graphics.setColor(c[1], c[2], c[3], 1)

  if e.arch == "chaser" then
    local ang = math.atan2(player.y - e.y, player.x - e.x)
    love.graphics.polygon("fill",
      e.x + math.cos(ang) * e.r,             e.y + math.sin(ang) * e.r,
      e.x + math.cos(ang + 2.4) * e.r * 0.7, e.y + math.sin(ang + 2.4) * e.r * 0.7,
      e.x + math.cos(ang - 2.4) * e.r * 0.7, e.y + math.sin(ang - 2.4) * e.r * 0.7)
  elseif e.arch == "shooter" then
    love.graphics.rectangle("fill", e.x - e.r, e.y - e.r, e.r * 2, e.r * 2, 2, 2)
  else
    if e.st == "windup" then
      love.graphics.setColor(COL.warn[1], COL.warn[2], COL.warn[3],
                             (0.5 + 0.5 * math.sin(e.stT * 30)))
      love.graphics.circle("line", e.x, e.y, e.r + 6 + e.stT * 60)
    elseif e.st == "charge" then
      love.graphics.setColor(1, 1, 1, 0.6)
      love.graphics.circle("fill", e.x, e.y, e.r * 1.15)
      love.graphics.setColor(c[1], c[2], c[3], 1)
    end
    love.graphics.circle("fill", e.x, e.y, e.r)
    if e.st == "charge" or e.st == "windup" then
      love.graphics.setColor(c[1], c[2], c[3], 0.5)
      love.graphics.line(e.x + e.cdirx * e.r, e.y + e.cdiry * e.r,
                         e.x + e.cdirx * (e.r + 16), e.y + e.cdiry * (e.r + 16))
    end
  end

  if e.flash > 0 then
    love.graphics.setColor(1, 1, 1, math.min(1, e.flash * 6))
    love.graphics.circle("fill", e.x, e.y, e.r)
  end
  for i = 1, e.maxhp do
    local px = e.x - (e.maxhp - 1) * 3 + (i - 1) * 6
    love.graphics.setColor(i <= e.hp and COL.hp or {0.25, 0.25, 0.25})
    love.graphics.rectangle("fill", px - 2, e.y - e.r - 9, 4, 3)
  end
  if e.aware then
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("line", e.x, e.y, e.r + 3)
  end
end

local function drawHUD()
  love.graphics.setColor(0.9, 0.9, 0.95, 1)
  -- hp pips
  love.graphics.print("HP", 8, 8)
  for i = 1, player.maxhp do
    local px = 30 + (i - 1) * 14
    love.graphics.setColor(i <= player.hp and COL.hp or {0.25, 0.25, 0.25})
    love.graphics.rectangle("fill", px, 10, 10, 12)
  end
  -- weapons + ammo
  local y = 30
  for _, name in ipairs(WEAPON_ORDER) do
    local w = WEAPONS[name]
    local sel = (name == player.weapon)
    love.graphics.setColor(sel and 1 or 0.5, sel and 1 or 0.5, sel and 1 or 0.5, sel and 1 or 0.6)
    love.graphics.print(("%s %d/%d"):format(w.name, player.ammo[name], w.max), 8, y)
    y = y + 14
  end
  -- kills + seed
  love.graphics.setColor(0.9, 0.9, 0.95, 0.8)
  love.graphics.print(("kills %d | seed %d | aggro %s")
    :format(kills, SEED, alwaysAggro and "ALWAYS" or "normal"), 8, VIEW_H - 34)
  love.graphics.print("click = fire | 1/2 = pulse/scatter | R = restart | G = aggro | F = ammo", 8, VIEW_H - 18)
end

function love.draw()
  love.graphics.setBackgroundColor(0.02, 0.02, 0.04)
  love.graphics.push()
  love.graphics.scale(SCALE, SCALE)
  love.graphics.push()
  love.graphics.translate(-math.floor(camX), -math.floor(camY))

  for ty = 1, ROWS do
    for tx = 1, COLS do
      local px, py = (tx - 1) * TILE, (ty - 1) * TILE
      love.graphics.setColor(grid[ty][tx] == FLOOR and COL.floor or COL.wall)
      love.graphics.rectangle("fill", px, py, TILE, TILE)
    end
  end
  love.graphics.setColor(COL.wallEdge[1], COL.wallEdge[2], COL.wallEdge[3], 0.7)
  for ty = 1, ROWS do
    for tx = 1, COLS do
      if grid[ty][tx] == WALL then
        love.graphics.rectangle("fill", (tx - 1) * TILE, (ty - 1) * TILE, TILE, 1.5)
        love.graphics.rectangle("fill", (tx - 1) * TILE, (ty - 1) * TILE, 1.5, TILE)
      end
    end
  end

  -- ammo crates
  for _, c in ipairs(crates) do
    if not c.taken then
      local col = (c.kind == "pulse") and COL.crate or COL.crate2
      love.graphics.setColor(col[1], col[2], col[3], 0.35 + 0.15 * math.sin(love.timer.getTime() * 4))
      love.graphics.rectangle("fill", c.x - 6, c.y - 6, 12, 12, 2, 2)
      love.graphics.setColor(col[1], col[2], col[3], 1)
      love.graphics.rectangle("line", c.x - 6, c.y - 6, 12, 12, 2, 2)
    end
  end

  for _, p in ipairs(projectiles) do
    love.graphics.setColor(p.col[1], p.col[2], p.col[3], 1)
    love.graphics.circle("fill", p.x, p.y, p.r)
  end

  for _, e in ipairs(enemies) do
    if e.hp > 0 then drawEnemy(e) end
  end

  -- player
  local mx, my = love.mouse.getPosition()
  local aimWx, aimWy = mx / SCALE + camX, my / SCALE + camY
  love.graphics.setColor(COL.player[1], COL.player[2], COL.player[3], 0.35)
  love.graphics.line(player.x, player.y, aimWx, aimWy)
  glow(COL.player, player.x, player.y, player.r)
  if player.iframes > 0 and math.floor(player.iframes * 20) % 2 == 0 then
    love.graphics.setColor(COL.player[1] * 3, COL.player[2] * 0.3, COL.player[3] * 0.3, 1)
  else
    love.graphics.setColor(COL.player[1], COL.player[2], COL.player[3], 1)
  end
  if player.flash > 0 then
    love.graphics.setColor(1, 1, 1, math.min(1, player.flash * 4))
  end
  love.graphics.circle("fill", player.x, player.y, player.r)
  -- muzzle flash
  if player.muzzle > 0 then
    local a = player.aim
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, player.muzzle * 8)
    love.graphics.circle("fill", player.x + math.cos(a) * (player.r + 6),
                                 player.y + math.sin(a) * (player.r + 6), 4)
    love.graphics.setBlendMode("alpha")
  end

  love.graphics.pop()  -- end camera translate

  if player.hp <= 0 then
    love.graphics.setColor(1, 0.15, 0.15, 0.75)
    love.graphics.printf("PERMADEATH", 0, VIEW_H / 2 - 20, VIEW_W, "center")
    love.graphics.setColor(0.9, 0.9, 0.95, 0.9)
    love.graphics.printf("R to restart", 0, VIEW_H / 2 + 6, VIEW_W, "center")
  end

  drawHUD()
  love.graphics.pop()
end

-- ---------------------------------------------------------------- boot
function love.load()
  love.window.setTitle("PROTOTYPE #11 — Combat & weapon model v1 (pulse/scatter)")
  love.window.setMode(VIEW_W * SCALE, VIEW_H * SCALE)
  love.graphics.setDefaultFilter("nearest", "nearest")
  reset()
end