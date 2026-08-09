-- lib/seeded.lua — single deterministic RNG spine (B2).
-- Every random draw in a run flows through this module; identical seed string
-- => identical run (docs/floor-model.md). Wraps love.math.random after
-- love.math.setRandomSeed. NEVER Lua's math.random and never love.math.noise
-- for layout — both break reproducibility (docs/research/room-generation.md
-- gotchas; the LÖVE seed is set here, love seeds the RNG with time otherwise).
--
-- Contract per docs/architecture.md: exposes load/update/draw(world, dt) and
-- is registered in main.lua. Modules never require this file directly — load()
-- wires it into the shared world as `world.seeded`; downstream modules call
-- world.seeded.rand/int/pick.

local PROBE_DRAWS = 8 -- "first N draws" shown by the debug readout

local seeded = {}

local debugLines = {} -- formatted first-N draws, for the debug panel
local total = 0       -- total draws so far (probe + every consumer draw)

-- String seed -> stable 32-bit integer. love.data.hash's string form takes
-- TWO args: hash(hashFunction, string) -> raw digest as a Lua string (the
-- 3-arg hash(hashFunction, datatype, data) form is for Data/File inputs;
-- passing 3 args here silently hashes the literal type name, not the seed!).
-- Fold the first 4 bytes into a 32-bit int for setRandomSeed. Deterministic
-- everywhere, so the same seed string always yields the same setRandomSeed.
local function hashSeed(s)
  local raw = love.data.hash("md5", s) -- 16 raw bytes for md5
  local n = 0
  for i = 1, 4 do
    n = n * 256 + string.byte(raw, i)
  end
  return n
end

local function record(kind, value)
  total = total + 1
  if #debugLines < PROBE_DRAWS then
    debugLines[#debugLines + 1] =
      string.format("%d %s %s", total, kind, tostring(value))
  end
end

function seeded.setSeed(seedStr)
  love.math.setRandomSeed(hashSeed(seedStr))
  debugLines = {}
  total = 0
  -- Probe draws: with no gameplay consumer yet (that's B4+), show the first
  -- draws so reproducibility is visible. These genuinely consume the RNG —
  -- deterministic, so later consumers just start from draw N+1.
  for _ = 1, PROBE_DRAWS do
    seeded.rand()
  end
end

function seeded.rand()
  local v = love.math.random() -- [0,1)
  record("rand", ("%.6f"):format(v))
  return v
end

-- int(n)  -> 1..n ;  int(m, n) -> m..n  (integers)
function seeded.int(a, b)
  local v = b and love.math.random(a, b) or love.math.random(a)
  record("int", v)
  return v
end

function seeded.pick(t)
  local v = t[love.math.random(#t)]
  record("pick", tostring(v))
  return v
end

-- --- module contract -----------------------------------------------------

function seeded.load(world)
  world.seeded = seeded
  seeded.setSeed(world.seed)
end

function seeded.update()
end

-- Debug panel: first-N draws, gate on world.debug (dev helpers only; the
-- real HUD owns on-screen state readouts from B12).
function seeded.draw(world)
  if not world.debug then return end
  love.graphics.setColor(0.30, 0.60, 0.38, 1) -- dim green, B6.1 restyle
  love.graphics.print("rng draws (" .. #debugLines .. " shown / " .. total .. " total)", 8, 72)
  for i, line in ipairs(debugLines) do
    love.graphics.print(line, 8, 72 + 14 * i)
  end
end

return seeded