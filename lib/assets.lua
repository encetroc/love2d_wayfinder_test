-- lib/assets.lua — procedural sprite + SFX pipeline (B3).
-- Every image is an ImageData built pixel-by-pixel in code, then bridged to
-- the GPU with love.graphics.newImage; every sfx is SoundData synthesized in
-- code -> love.audio.newSource (always "static" from SoundData). Nothing is
-- ever loaded from a file (hard repo rule) and everything is built ONCE in
-- init()/love.load — never per frame.
-- Pipeline per docs/research/sprite-pipeline.md; sfx set per
-- docs/research/audio-scope.md (floor ambience + music CUT for scope).
--
-- Contract per docs/architecture.md: load/update/draw(world, dt), plus an
-- optional keypressed(world, key) hook (input lives in modules). load()
-- wires world.assets = assets; downstream modules never require this file.

local RATE = 44100

local PAL = {
  floor    = { 0.06, 0.05, 0.10 },
  wall     = { 0.12, 0.11, 0.16 },
  wallEdge = { 0.35, 0.90, 1.00 },
  wallFar  = { 0.05, 0.05, 0.08 },
  player   = { 0.20, 1.00, 1.00 },
  chaser   = { 1.00, 0.30, 0.90 },
  shooter  = { 1.00, 0.55, 0.20 },
  tank     = { 1.00, 0.25, 0.25 },
  proj     = { 1.00, 0.95, 0.75 },
  white    = { 1.00, 1.00, 1.00 },
}

local assets = {
  images = {}, -- key -> Image
  sfx    = {}, -- key -> static Source
  buildCount = 0, -- init() ran N times (smoke: must stay 1)
}

-- --- image builder --------------------------------------------------------

-- pixelFn(x, y) -> r,g,b,a, all 0..1 floats; x/y are 0-indexed per
-- ImageData. Builds the ImageData and bridges to a GPU Image.
local function buildImage(w, h, pixelFn)
  local id = love.image.newImageData(w, h) -- rgba8
  for y = 0, h - 1 do
    for x = 0, w - 1 do
      local r, g, b, a = pixelFn(x, y)
      id:setPixel(x, y, r, g, b, a)
    end
  end
  return love.graphics.newImage(id)
end

-- Baked-halo entity: flat opaque core where coreFn(x,y) is true, then an
-- alpha-fading glow ring 3px out from the centroid until EDGE_FALLOFF px.
local function buildEntity(pal, coreFn, edgeFalloff)
  edgeFalloff = edgeFalloff or 3
  local cx, cy = 7.5, 7.5
  return buildImage(16, 16, function(x, y)
    if coreFn(x, y) then
      return pal[1], pal[2], pal[3], 1
    end
    local d = math.sqrt((x - cx) ^ 2 + (y - cy) ^ 2)
    local a = math.max(0, 1 - (d - 4.5) / edgeFalloff) * 0.5
    return pal[1], pal[2], pal[3], a
  end)
end

-- sfx noise source: deterministic LOCAL LCG. Never love.math.random — the
-- run RNG belongs to lib/seeded.lua and assets.init() runs AFTER the run is
-- seeded, so drawing here would shift every later consumer's stream (this
-- actually broke floor-gen determinism in B4 — see commit note).
local noiseState = 12345
local function sfxNoise()
  noiseState = (noiseState * 1103515245 + 12345) % 2147483648
  return noiseState / 1073741823.5 - 1 -- -1..1
end

-- --- gen: tiles -----------------------------------------------------------

local function genFloor()
  return buildImage(16, 16, function(x, y)
    -- love.math.noise is fine here: ambient tile texture only, never layout
    -- (docs/research/room-generation.md). Not seedable -> same texture every
    -- run, which is exactly what a static tile wants.
    local n = love.math.noise(x * 0.4, y * 0.4)
    local v = n * 0.012
    return PAL.floor[1] + v, PAL.floor[2] + v, PAL.floor[3] + v, 1
  end)
end

local function genWall()
  return buildImage(16, 16, function(x, y)
    if x == 0 or y == 0 then return PAL.wallEdge[1], PAL.wallEdge[2], PAL.wallEdge[3], 1 end
    if x == 15 or y == 15 then return PAL.wallFar[1], PAL.wallFar[2], PAL.wallFar[3], 1 end
    return PAL.wall[1], PAL.wall[2], PAL.wall[3], 1
  end)
end

-- --- gen: entities --------------------------------------------------------

local function genPlayer()
  return buildEntity(PAL.player, function(x, y)
    local dx, dy = math.abs(x - 7.5), math.abs(y - 7.5)
    if dx + dy <= 3 then return true end -- flat diamond core
    return false
  end, 3)
end

local function genEnemyChaser()
  return buildEntity(PAL.chaser, function(x, y)
    -- point-up triangle: apex ~y=1, base ~y=13
    if y < 1 or y > 13 then return false end
    return math.abs(x - 7.5) <= (y - 1) * (5.5 / 11.5)
  end, 3)
end

local function genEnemyShooter()
  return buildEntity(PAL.shooter, function(x, y)
    local dx, dy = math.abs(x - 7.5), math.abs(y - 7.5)
    if dx <= 3.5 and dy <= 3.5 then
      return true
    end
    return false
  end, 3)
end

local function genEnemyTank()
  return buildEntity(PAL.tank, function(x, y)
    local dx = math.abs(x - 7.5)
    if math.abs(y - 7.5) <= 5.5 - dx * 0.5 then return true end -- hexagon-ish block
    return false
  end, 4)
end

local function genProjectile()
  -- 8x8: bright core + short soft tail (tinted per faction with setColor at draw)
  return buildImage(8, 8, function(x, y)
    local d = math.sqrt((x - 2.5) ^ 2 + (y - 3.5) ^ 2)
    if d <= 1.8 then
      return PAL.proj[1], PAL.proj[2], PAL.proj[3], 1
    end
    local a = math.max(0, 1 - (d - 1.8) / 1.6) * 0.8
    return PAL.proj[1], PAL.proj[2], PAL.proj[3], a
  end)
end

local function genGlow()
  -- pure white alpha-only radial gradient; tint at draw with setColor and
  -- add additively (setBlendMode("add")) for emissive fx
  return buildImage(16, 16, function(x, y)
    local d = math.sqrt((x - 7.5) ^ 2 + (y - 7.5) ^ 2)
    local a = math.max(0, 1 - d / 7.5) ^ 2
    return 1, 1, 1, a
  end)
end

local function genParticle()
  -- 4x4 soft dot (feeds ParticleSystems later)
  return buildImage(4, 4, function(x, y)
    local d = math.sqrt((x - 1.5) ^ 2 + (y - 1.5) ^ 2)
    local a = math.max(0, 1 - d / 1.8)
    return 1, 1, 1, a
  end)
end

-- --- sfx builder ----------------------------------------------------------

-- Synthesis helper (docs/research/audio-scope.md): sine or square, freq sweeps
-- fStart->fEnd over dur, decay envelope; optional noise mix for impacts.
-- Returns a static Source (all sources from SoundData are static).
local function makeSound(dur, fStart, fEnd, vol, wave, noiseMix)
  noiseMix = noiseMix or 0
  local n = math.floor(dur * RATE)
  local sd = love.sound.newSoundData(n, RATE, 16, 1)
  for i = 0, n - 1 do
    local t = i / RATE
    local prog = i / n
    local f = fStart + (fEnd - fStart) * prog
    local s = math.sin(2 * math.pi * f * t)
    if wave == "square" then s = s > 0 and 1 or -1 end
    if noiseMix > 0 then
      s = (1 - noiseMix) * s + noiseMix * sfxNoise()
    end
    local env = math.max(0, 1 - prog) * vol
    sd:setSample(i, math.max(-1, math.min(1, s * env)))
  end
  return love.audio.newSource(sd)
end

-- --- build once -----------------------------------------------------------

function assets.init()
  if assets.buildCount > 0 then return end -- built once, never rebuilt
  assets.buildCount = 1

  local img = assets.images
  img.floor          = genFloor()
  img.wall           = genWall()
  img.player         = genPlayer()
  img.enemy_chaser   = genEnemyChaser()
  img.enemy_shooter  = genEnemyShooter()
  img.enemy_tank     = genEnemyTank()
  img.projectile     = genProjectile()
  img.glow           = genGlow()
  img.particle       = genParticle()

  local sfx = assets.sfx
  sfx.shoot        = makeSound(0.10, 900, 200, 0.5, "square", 0.10) -- descending laser
  sfx.enemy_hit    = makeSound(0.08, 500, 300, 0.5, "sine")          -- short impact
  sfx.enemy_death  = makeSound(0.30, 300, 60, 0.7, "square", 0.35)   -- longer, lower
  sfx.pickup       = makeSound(0.18, 600, 900, 0.5, "square")        -- rising collect
  sfx.hurt         = makeSound(0.25, 250, 90, 0.6, "sine")           -- low hit
  sfx.player_death = makeSound(0.35, 200, 40, 0.8, "square", 0.50)   -- most prominent
end

-- Play a one-shot safely: restart even if the same source is still going.
function assets.play(name)
  local src = assets.sfx[name]
  if src then
    src:stop()
    src:play()
  end
end

-- Emissive overlay: draw a tintable glow additively on top of a sprite.
-- Caller sets setColor before; we restore the blend mode after.
function assets.drawGlow(image, x, y, scale)
  love.graphics.setBlendMode("add")
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.draw(image, x, y, 0, scale or 1, scale or 1)
  love.graphics.setBlendMode("alpha")
end

-- --- module contract ------------------------------------------------------

function assets.load(world)
  world.assets = assets
  assets.init()
end

function assets.update()
end

-- Debug-only test strip was B3 tooling: proved every primitive renders and
-- sfx audition keys work. The map now owns the canvas (B4), so draw is a
-- no-op; F1-F6 stay as a debug sfx audition (B6 remapped them off the number
-- row — 1/2 are now the weapon swap). Generation itself is a load-time
-- event, never per-frame (buildCount guard above).
function assets.draw()
end

-- Debug keys: play each sfx on demand (B3 verify: "SFX play on demand").
function assets.keypressed(world, key)
  if not world.debug then return end
  local map = {
    ["f1"] = "shoot", ["f2"] = "enemy_hit", ["f3"] = "enemy_death",
    ["f4"] = "pickup", ["f5"] = "hurt", ["f6"] = "player_death",
  }
  local name = map[key]
  if name then assets.play(name) end
end

return assets