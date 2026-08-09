-- ============================================================================
-- PROTOTYPE: Enemy AI — 3 archetypes (chaser / shooter / tank)  v2
-- Throwaway code answering: "does this AI framework + these numbers feel right?"
-- Ticket: wayfinder #6. Run with:  love prototypes/enemy-ai
-- v2 changes (from playtest): room-scoped + ranged AWARENESS (no cross-room
--   chasing, no wall hugging); tank reworked as an area-denial CHARGER.
-- Keys: WASD/arrows = move, mouse = aim, click = shoot (1 dmg),
--       R = regenerate same seed, G = always-aggro toggle.
-- ============================================================================

local TILE      = 16
local COLS      = 30
local ROWS      = 22
local W, H      = COLS * TILE, ROWS * TILE     -- 480 x 352
local SCALE     = 2                             -- window = 960 x 704

local SEED      = 20240807
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
  shot     = {1.00, 1.00, 0.40},
  proj     = {1.00, 0.80, 0.20},
  hp       = {0.40, 1.00, 0.40},
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
  rect(2, 2, 11, 9, FLOOR, 1)              -- room A (left, player start)
  rect(17, 2, 27, 11, FLOOR, 2)            -- room B (right)
  rect(5, 13, 13, 19, FLOOR, 3)            -- room C (bottom)
  rect(12, 5, 16, 5, FLOOR, 1)             -- corridor A->B
  rect(7, 10, 7, 12, FLOOR, 1)             -- corridor A->C
  local pillars = { {5,6}, {9,4}, {20,6}, {23,4}, {6,16}, {11,15}, {14,17} }
  for _, p in ipairs(pillars) do grid[p[2]][p[1]] = WALL end
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
local player, enemies, projectiles
local alwaysAggro = false

local SPAWN_SLOTS = { "chaser", "chaser", "shooter", "shooter", "tank", "tank", "chaser" }
local ROOM_CENTERS = { {6, 5}, {22, 6}, {9, 16} }

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
  for i, arch in ipairs(SPAWN_SLOTS) do
    local rc = ROOM_CENTERS[(i - 1) % #ROOM_CENTERS + 1]
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

local function reset()
  buildFloor()
  player = { x = 3 * TILE + 8, y = 4 * TILE + 8, r = 6, speed = 120 }
  projectiles = {}
  spawnEnemies()
end

-- ---------------------------------------------------------------- update
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
                                r = 2.5, from = "enemy", life = 3 })
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
    -- slow nudge to keep a mid-range, else hold ground
    if dist > 95 then e.vx, e.vy = ux * e.speed * 0.5, uy * e.speed * 0.5
    elseif dist < 50 then e.vx, e.vy = -ux * e.speed * 0.4, -uy * e.speed * 0.4
    else e.vx, e.vy = 0, 0 end
    if e.stT >= 2.0 then e.st, e.stT = "windup", 0 end    -- charge timer
  elseif e.st == "windup" then
    e.stT = e.stT + dt
    e.vx, e.vy = 0, 0
    if e.stT >= 0.55 then                                 -- telegraph done -> lunge
      e.st, e.stT = "charge", 0
      e.cdirx, e.cdiry = ux, uy                            -- lock direction at player NOW
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

  -- separation
  local forces = { x = 0, y = 0 }
  separation(e, forces)
  local fLen = math.sqrt(forces.x ^ 2 + forces.y ^ 2)
  if fLen > 0.001 then
    e.vx = e.vx + (forces.x / fLen) * 30
    e.vy = e.vy + (forces.y / fLen) * 30
  end

  -- move with wall slide
  local nx, ny = e.x + e.vx * dt, e.y + e.vy * dt
  if not (blocked(nx + e.r, e.y) or blocked(nx - e.r, e.y)) then e.x = nx end
  if not (blocked(e.x, ny + e.r) or blocked(e.x, ny - e.r)) then e.y = ny end
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
            e.hp = e.hp - 1
            e.flash = 0.12
            hit = true
            break
          end
        end
      end
    else
      local d2 = (p.x - player.x) ^ 2 + (p.y - player.y) ^ 2
      if d2 < (player.r + p.r) ^ 2 then hit = true end
    end
    if hit or p.life <= 0 or blocked(p.x, p.y) then table.remove(projectiles, i) end
  end
end

local function updatePlayer(dt)
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
end

function love.update(dt)
  updatePlayer(dt)
  for _, e in ipairs(enemies) do
    if e.hp > 0 then updateEnemy(e, dt) end
  end
  updateProjectiles(dt)
end

-- ---------------------------------------------------------------- input
function love.keypressed(key)
  if key == "r" then reset() end
  if key == "g" then alwaysAggro = not alwaysAggro end
end

function love.mousepressed(mx, my, button)
  if button ~= 1 then return end
  local wx, wy = mx / SCALE, my / SCALE
  local dx, dy = wx - player.x, wy - player.y
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.001 then return end
  dx, dy = dx / len, dy / len
  table.insert(projectiles, { x = player.x + dx * 10, y = player.y + dy * 10,
                              vx = dx * 260, vy = dy * 260, r = 3,
                              from = "player", life = 1.2 })
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
  else -- tank: telegraph wind-up with a pulsing warn ring, then lunge
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
    -- charge direction hint
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
  -- hp pips
  for i = 1, e.maxhp do
    local px = e.x - (e.maxhp - 1) * 3 + (i - 1) * 6
    love.graphics.setColor(i <= e.hp and COL.hp or {0.25, 0.25, 0.25})
    love.graphics.rectangle("fill", px - 2, e.y - e.r - 9, 4, 3)
  end
  -- awareness indicator
  if e.aware then
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("line", e.x, e.y, e.r + 3)
  end
end

function love.draw()
  love.graphics.setBackgroundColor(0.02, 0.02, 0.04)
  love.graphics.push()
  love.graphics.scale(SCALE, SCALE)

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

  for _, p in ipairs(projectiles) do
    love.graphics.setColor(p.from == "player" and COL.shot or COL.proj)
    love.graphics.circle("fill", p.x, p.y, p.r)
  end

  for _, e in ipairs(enemies) do
    if e.hp > 0 then drawEnemy(e) end
  end

  local mx, my = love.mouse.getPosition()
  love.graphics.setColor(COL.player[1], COL.player[2], COL.player[3], 0.35)
  love.graphics.line(player.x, player.y, mx / SCALE, my / SCALE)
  glow(COL.player, player.x, player.y, player.r)
  love.graphics.setColor(COL.player[1], COL.player[2], COL.player[3], 1)
  love.graphics.circle("fill", player.x, player.y, player.r)

  local alive = 0
  for _, e in ipairs(enemies) do if e.hp > 0 then alive = alive + 1 end end
  love.graphics.setColor(0.9, 0.9, 0.95, 1)
  love.graphics.print(("seed %d | enemies %d alive | aggro %s | room-aware")
    :format(SEED, alive, alwaysAggro and "ALWAYS" or "normal"), 6, H - 18)
  love.graphics.print("click = shoot (1 dmg) | R = regenerate | G = always aggro", 6, H - 32)

  love.graphics.pop()
end

-- ---------------------------------------------------------------- boot
function love.load()
  love.window.setTitle("PROTOTYPE #6 — Enemy AI v2 (chaser/shooter/tank)")
  love.window.setMode(W * SCALE, H * SCALE)
  love.graphics.setDefaultFilter("nearest", "nearest")
  reset()
end