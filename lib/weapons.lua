-- lib/weapons.lua — weapon defs + firing (B6).
-- Ports prototype/combat-weapons fire logic per docs/combat-weapons.md:
-- PULSE (accurate single shot, ranged killer) and SCATTER (5-pellet ±9° fan,
-- close-range burst). Per-weapon capped ammo reserve, 1 unit per trigger pull
-- (a scatter blast costs ONE shell, not one per pellet). Firing spawns
-- projectiles into world.projectiles — lib/projectiles.lua owns motion +
-- wall-death; enemy collision is B8 (motion only this ticket).
--
-- Aim is the mouse (world-space, converted from window coords through the
-- camera + letterbox math — the inverse of main.lua's canvas blit). Jitter on
-- the scatter fan draws from world.seeded (hard rule: every random draw flows
-- through the single run RNG; same seed => same blast).
--
-- Contract: load/update/draw(world, dt) + mousepressed + optional keypressed
-- (debug ammo refill). load() wires world.weapons and seeds player ammo;
-- must load after lib/player.lua (reads world.player).

local weapons = {
  ORDER = { "pulse", "scatter" },
  DEFS = {
    pulse = {
      name = "PULSE", cd = 0.22, dmg = 1, speed = 300, pr = 3, life = 0.9,
      pellets = 1, spread = 0, col = { 1.00, 1.00, 1.00 }, -- white tracer
      ammo = 30, max = 60,
    },
    scatter = {
      name = "SCATTER", cd = 0.55, dmg = 1, speed = 260, pr = 2, life = 0.35,
      pellets = 5, spread = 0.16, col = { 0.90, 1.00, 0.85 }, -- pale green pellets
      ammo = 8, max = 16,
    },
  },
}

-- window px -> base-res px -> world px (inverse of main.lua's canvas blit
-- plus the camera transform; duplicated here and in mousepressed because main
-- is the only licensee of the numbers — camera.toWorld does the camera half)
local function windowToWorld(world, mx, my)
  local w, h = love.graphics.getDimensions()
  local scale = math.min(w / world.VIEW_W, h / world.VIEW_H)
  local ox = (w - world.VIEW_W * scale) * 0.5
  local oy = (h - world.VIEW_H * scale) * 0.5
  return world.camera.toWorld((mx - ox) / scale, (my - oy) / scale)
end

-- --- module contract ------------------------------------------------------

function weapons.load(world)
  world.weapons = weapons
  local p = world.player -- lib/player ran first
  p.weapon = "pulse"
  p.cd, p.muzzle, p.aim = 0, 0, 0 -- cooldown / muzzle-flash / last aim angle
  p.ammo = {}
  for _, name in ipairs(weapons.ORDER) do
    p.ammo[name] = weapons.DEFS[name].ammo -- start reserve
  end
end

-- Fire the current weapon (exposed for tests/smoke; mousepressed computes the
-- angle from the cursor). Empty weapon simply won't fire — no reload, no jam;
-- swap away (1/2) or find ammo (docs/combat-weapons.md).
function weapons.fire(world, ang)
  local p = world.player
  local w = weapons.DEFS[p.weapon]
  if p.cd > 0 then return end
  if p.ammo[p.weapon] <= 0 then return end

  p.ammo[p.weapon] = p.ammo[p.weapon] - 1 -- one trigger pull, even for pellets
  p.cd = w.cd
  p.muzzle = 0.05
  p.aim = ang

  for i = 1, w.pellets do
    local a = ang
    if w.pellets > 1 then
      -- deterministic ±9° fan steps + small seeded jitter (rule 3)
      local step = w.spread * 2 / (w.pellets - 1)
      a = ang + (i - (w.pellets + 1) / 2) * step
        + (world.seeded.rand() - 0.5) * 0.08
    end
    -- spread-aware spawn: each pellet leaves the muzzle along ITS OWN angle,
    -- so the scatter fan is visible from the barrel, not a single point
    local o = p.RADIUS + 4
    world.projectiles[#world.projectiles + 1] = {
      x = p.x + math.cos(a) * o, y = p.y + math.sin(a) * o,
      vx = math.cos(a) * w.speed, vy = math.sin(a) * w.speed,
      r = w.pr, life = w.life, from = "player", dmg = w.dmg, col = w.col,
    }
  end
  world.assets.play("shoot")
end

-- Cooldown + muzzle-timer decay (fire itself is input-driven, mousepressed)
function weapons.update(world, dt)
  local p = world.player
  p.cd = math.max(0, p.cd - dt)
  p.muzzle = math.max(0, p.muzzle - dt)
end

function weapons.draw(world)
  local p = world.player
  world.camera.apply() -- world space (same transform as map/player)
  -- faint green-white aim line to the cursor (B6.1 restyle; the fan/accuracy
  -- split still reads at a glance)
  local wx, wy = windowToWorld(world, love.mouse.getPosition())
  love.graphics.setColor(0.55, 1.00, 0.70, 0.22)
  love.graphics.line(p.x, p.y, wx, wy)
  -- muzzle flash: white-hot core with a green ring (Antecrypt burst language)
  if p.muzzle > 0 then
    local a = p.aim
    local fx = p.x + math.cos(a) * (p.RADIUS + 8)
    local fy = p.y + math.sin(a) * (p.RADIUS + 8)
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, math.min(1, p.muzzle * 8))
    love.graphics.circle("fill", fx, fy, 3.5)
    love.graphics.setColor(0.45, 1.00, 0.55, math.min(1, p.muzzle * 4) * 0.6)
    love.graphics.circle("line", fx, fy, 7)
    love.graphics.setBlendMode("alpha")
  end
  world.camera.pop()
end

-- Left-click fires toward the cursor (window -> world through the canvas blit)
function weapons.mousepressed(world, mx, my, button)
  if button ~= 1 then return end
  local wx, wy = windowToWorld(world, mx, my)
  local p = world.player
  weapons.fire(world, math.atan2(wy - p.y, wx - p.x))
end

-- Debug helper (prototype's F): refill both reserves so ammo-cap behavior
-- stays testable without hunting crates (real pickups are B9)
function weapons.keypressed(world, key)
  if not world.debug or key ~= "f" then return end
  local p = world.player
  for _, name in ipairs(weapons.ORDER) do
    p.ammo[name] = weapons.DEFS[name].max
  end
end

return weapons