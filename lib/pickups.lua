-- lib/pickups.lua — pickups: seeded placement + overlap collect (B9).
-- Implements docs/progression-pickups.md (ticket #4) on the shared-world
-- contract. Every non-spawn room gets 1-2 seeded pickups drawn from a weighted
-- pool (pulse ammo / scatter ammo / health); the damage upgrade is GUARANTEED
-- exactly once per run in a room at >= half the floor (spawn chain: room.id
-- 1 = spawn ... count = exit, so id >= ceil(count/2) is the far half) and
-- occupies that room's first slot — no stacking, one per run. Ammo/health
-- over a cap still consume the pickup and clamp at collect time (the
-- prototype's crate behavior; nothing is reserved).
--
-- Ticket #22 says the pool is "(ammo/health/upgrade)" and the doc pins
-- "upgrade guaranteed once, placed in a room at >= half the floor". Doc wins:
-- the upgrade is not a weighted roll (it could roll zero — the ticket demands
-- "guaranteed once"), it's a seeded far-half placement; the pool rolls are
-- ammo/health only. Same shape as B8's "doc wins over prototype" deviation.
--
-- Effects (locked in #4): health +2 HP (cap 4 = maxhp), pulse ammo +6 (cap
-- 60 = weapons.DEFS.pulse.max), scatter ammo +2 (cap 16), damage upgrade +1
-- (pulse 1->2, every scatter pellet 1->2 — read as `p.dmgUp` at fire time by
-- lib/weapons.lua; set to 1, never incremented, so "no stacking" holds).
--
-- Placement draws ALL flow through world.seeded (rule 3) and mirror
-- lib/enemy.lua's spawn: room center tile +-2 jitter with retry, accepting
-- only tiles INSIDE the assigned room (all FLOOR by gen, so in-room implies
-- walkable; the explicit walkable check stays for parity with #6's text) —
-- never corridors, never walls. The spawn room gets no pickups (#4: it's
-- enemy-free, so free loot there is dead value).
--
-- Contract: load/update/draw(world, dt) + keypressed (debug R respawns after
-- map regenerate + enemy respawn replay the same RNG stream). load() wires
-- world.pickups and world.player.dmgUp, then spawns; must load after
-- lib/map.lua (reads world.map.floor), lib/seeded.lua (all draws), and
-- lib/player.lua + lib/weapons.lua (sets p.dmgUp; effects touch p.hp/ammo).
-- main.lua registers it last. No audio yet: B11 wires the pickup sfx hooks
-- (weapons.lua already plays B3's `pickup` sfx through world.assets, same
-- precedent).

local pickups = {}

-- Weighted pool for the 1-2 per-room slots (weights relative; sum to 100).
-- Scarcity-first: ammo dominates (the run's progression lever per #4).
local POOL = {
  { kind = "pulse",   w = 40 },
  { kind = "scatter", w = 30 },
  { kind = "health",  w = 30 },
}
local POOL_TOTAL = 0
for _, p in ipairs(POOL) do POOL_TOTAL = POOL_TOTAL + p.w end

local PICK_R = 8 -- collect radius added to the player's RADIUS (prototype's
                -- player.r + 8 collect window, #11 approved feel)

-- --- helpers ---------------------------------------------------------------

-- One weighted roll from POOL (a single seeded.int draw per slot — the draw
-- count is part of the deterministic stream, same as enemy jitter).
local function pooledKind(seed)
  local roll = seed.int(1, POOL_TOTAL)
  local acc = 0
  for _, p in ipairs(POOL) do
    acc = acc + p.w
    if roll <= acc then return p.kind end
  end
  return POOL[#POOL].kind -- belt+braces; acc reaches POOL_TOTAL, unreachable
end

-- Seeded placement INSIDE the room: center tile +-2 jitter with retry
-- (mirrors lib/enemy.lua spawnEnemies byte-for-byte in shape).
local function placePickup(world, room, kind)
  local cx = room.rect.x + math.floor(room.rect.w / 2) -- room center tile
  local cy = room.rect.y + math.floor(room.rect.h / 2)
  local tx, ty = cx, cy
  for _ = 1, 8 do
    local jx, jy = world.seeded.int(-2, 2), world.seeded.int(-2, 2)
    local ntx, nty = cx + jx, cy + jy
    if ntx >= room.rect.x and ntx < room.rect.x + room.rect.w
       and nty >= room.rect.y and nty < room.rect.y + room.rect.h
       and world.map.isWalkablePx((ntx - 1) * world.TILE + world.TILE / 2,
                                  (nty - 1) * world.TILE + world.TILE / 2) then
      tx, ty = ntx, nty
      break
    end
  end
  return {
    kind = kind, room = room.id,
    x = (tx - 1) * world.TILE + world.TILE / 2,
    y = (ty - 1) * world.TILE + world.TILE / 2,
    taken = false,
  }
end

-- Shuffle-free seeded placement; draw order is part of the seed stream, so
-- identical seed => identical list (verify: same seed replays exactly).
-- 1) pick the upgrade room among far-half rooms (guaranteed non-empty: the
--    exit room, id = count, always qualifies);
-- 2) each non-spawn room rolls 1-2 slots; the upgrade room's FIRST slot is
--    the upgrade, the rest roll the pool.
local function spawnPickups(world)
  local rooms, far = {}, {}
  local count = #world.map.floor.rooms
  local half = math.ceil(count / 2)
  for _, r in ipairs(world.map.floor.rooms) do
    if not r.spawn then
      rooms[#rooms + 1] = r
      if r.id >= half then far[#far + 1] = r end
    end
  end
  local upgradeRoom = far[world.seeded.int(#far)]
  local list = {}
  for _, r in ipairs(rooms) do
    for s = 1, world.seeded.int(1, 2) do
      local kind = (r == upgradeRoom and s == 1) and "upgrade" or pooledKind(world.seeded)
      list[#list + 1] = placePickup(world, r, kind)
    end
  end
  return list
end

-- --- collect ---------------------------------------------------------------

-- Apply the pickup's effect at collect time, caps clamped (never reserved).
-- player.dmgUp is SET to 1 (not incremented): exactly one upgrade per run, no
-- stacking by construction — a second upgrade pickup would no-op.
local function applyEffect(world, pk)
  local p = world.player
  if pk.kind == "health" then
    p.hp = math.min(p.maxhp, p.hp + 2)
  elseif pk.kind == "pulse" then
    p.ammo.pulse = math.min(world.weapons.DEFS.pulse.max, p.ammo.pulse + 6)
  elseif pk.kind == "scatter" then
    p.ammo.scatter = math.min(world.weapons.DEFS.scatter.max, p.ammo.scatter + 2)
  elseif pk.kind == "upgrade" then
    p.dmgUp = 1
  end
  world.assets.play("pickup")
end

-- --- module contract -------------------------------------------------------

function pickups.load(world)
  world.pickups = {}
  world.player.dmgUp = 0 -- B9: damage upgrade flag read by weapons.fire (+1)
  pickups.spawn(world)
end

-- (Re)spawn all pickups from world.seeded (exposed for R replay + tests).
function pickups.spawn(world)
  world.pickups = spawnPickups(world)
end

-- Overlap + auto-collect (no key, #11 prototype parity): walking over a
-- pickup applies its effect immediately. A corpse doesn't vacuum loot (same
-- gate as player movement); caps clamp at collect time.
function pickups.update(world, dt)
  local p = world.player
  if p.hp and p.hp <= 0 then return end
  local rr = (p.RADIUS + PICK_R) ^ 2
  for _, pk in ipairs(world.pickups) do
    if not pk.taken then
      local dx, dy = pk.x - p.x, pk.y - p.y
      if dx * dx + dy * dy < rr then
        pk.taken = true
        applyEffect(world, pk)
      end
    end
  end
end

function pickups.draw(world)
  if not world.camera or not world.player then return end
  local imgs = world.assets.images
  world.camera.apply() -- world-space content below; camera.pop() at the end
  for _, pk in ipairs(world.pickups) do
    if not pk.taken then
      -- emissive under-glow + sprite, same entity language as player/enemies
      world.assets.drawGlow(imgs.glow, pk.x - 8, pk.y - 8, 1.1)
      love.graphics.setColor(1, 1, 1, 1)
      love.graphics.draw(imgs["pickup_" .. pk.kind], pk.x - 8, pk.y - 8)
    end
  end
  world.camera.pop()
end

-- Debug R: respawn pickups from the current seed. map.keypressed re-seeds
-- world.seeded and regenerates the floor first, enemy.keypressed respawns
-- enemies — the whole RNG stream replays from draw 1 (map -> enemy -> pickup),
-- so R shows the identical pickup layout as fresh boot (B9 verify).
function pickups.keypressed(world, key)
  if world.debug and key == "r" then
    pickups.spawn(world)
  end
end

return pickups