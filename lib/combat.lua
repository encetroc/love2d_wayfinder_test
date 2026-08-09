-- lib/combat.lua — combat & damage flow (B8).
-- Ports prototype/combat-weapons hit resolution per docs/combat-weapons.md.
-- Owns every hit in the game:
--   * projectile-vs-enemy  (player shots: pulse 1 dmg, scatter 5 x 1) — circle
--     overlap (squared radius), HP in integer hits (#11), 0.12s enemy
--     hit-flash, kill count -> world.run.kills
--   * projectile-vs-player (shooter's 1 dmg bullet)
--   * contact-vs-player    (chaser touch 1, tank charge 2 — the tank is
--     harmless while holding/recovering) + 0.5s i-frames and 0.25s hurt flash
-- The tile grid is NOT a hitscan layer: it never resolves hits, only blocks
-- movement (lib/map.lua, lib/player.lua) and kills projectiles on WALL tiles
-- (lib/projectiles.lua). Friendly fire off: player projectiles only hit
-- enemies, enemy projectiles only hit the player.
--
-- Deviation from the prototype (doc wins, prototype slips): the reference's
-- contact loop lumped every non-tank archetype into "touch deals 1", so a
-- shooter standing on the player would deal contact damage. The locked damage
-- table (docs/combat-weapons.md) is chaser contact 1 / shooter projectile 1 /
-- tank charge 2 — shooter contact is NOT a damage source here.
--
-- Contract: load/update/draw(world, dt). load() wires world.combat and seeds
-- the player's damage state (hp 4 / iframes / flash) + world.run.kills —
-- lib/run.lua (B10) owns the full run FSM and will grow the world.run blob;
-- combat only reads/creates it. Must load after lib/player.lua (world.player),
-- lib/projectiles.lua (world.projectiles), lib/enemy.lua (world.enemies) —
-- main.lua registers it last. No audio: B11 wires the hurt/hit/death sfx.

local combat = {}

-- Locked player damage model (docs/combat-weapons.md): 4 integer HP, 0.5s
-- i-frames after ANY hit (kills stun-lock from chaser swarms and multi-hit
-- from one tank charge), 0.25s red hurt flash. Enemy side: 0.12s white
-- hit-flash (B7's draw already renders e.flash; combat drives it).
local PLAYER_HP, IFRAMES, HURT_FLASH = 4, 0.5, 0.25
local ENEMY_FLASH = 0.12

-- Enemy->player damage by archetype. Tank's 2 is the charge smash — half your
-- bar; the 0.55s telegraph is the counterplay (#6/#11).
local CONTACT_DMG = { chaser = 1, tank = 2 }

-- Apply damage to the player: one integer hit, then 0.5s of invulnerability
-- (a second hit inside that window does nothing — the charge can't chunk you
-- twice and a swarm can't stun-lock). HP clamps at 0 = player death; B10's
-- DEAD state reads this.
local function hurtPlayer(world, dmg)
  local p = world.player
  if p.hp <= 0 or p.iframes > 0 then return end
  p.hp = math.max(0, p.hp - dmg)
  p.iframes = IFRAMES
  p.flash = HURT_FLASH
end

-- Projectile hits. One pass over world.projectiles (iterated end-first so
-- table.remove is safe); a projectile that connects is consumed on contact.
-- Player shots test every living enemy (a scatter blast resolves each pellet
-- independently — 5 x 1 hits, kills counted exactly once when hp first hits
-- 0; later pellets pass over the corpse). Enemy shots test the player only.
local function resolveProjectileHits(world)
  local list = world.projectiles
  local p = world.player
  for i = #list, 1, -1 do
    local proj = list[i]
    local hit = false
    if proj.from == "player" then
      for _, e in ipairs(world.enemies) do
        if e.hp > 0 then
          local dx, dy = proj.x - e.x, proj.y - e.y
          if dx * dx + dy * dy < (e.r + proj.r) ^ 2 then
            e.hp = e.hp - proj.dmg -- integer hits; projectile dmg is 1
            e.flash = ENEMY_FLASH
            if e.hp <= 0 then world.run.kills = world.run.kills + 1 end
            hit = true
            break
          end
        end
      end
    else -- enemy projectile -> player (shooter's 1 dmg bullet)
      local dx, dy = proj.x - p.x, proj.y - p.y
      if dx * dx + dy * dy < (p.RADIUS + proj.r) ^ 2 then
        hurtPlayer(world, proj.dmg)
        hit = true
      end
    end
    if hit then table.remove(list, i) end
  end
end

-- Contact damage (melee): circle-overlap vs the player's hitbox, gated on the
-- enemy being alive AND aware (a de-aggro'd enemy doesn't hurt you — it
-- already isn't pursuing). Chaser = touch; tank = ONLY the charge lunge (it
-- holds ground and telegraphs otherwise); shooter has no contact damage.
local function resolveContactHits(world)
  local p = world.player
  if p.hp <= 0 or p.iframes > 0 then return end
  for _, e in ipairs(world.enemies) do
    if e.hp > 0 and e.aware then
      local dx, dy = e.x - p.x, e.y - p.y
      local rr = e.r + p.RADIUS
      if dx * dx + dy * dy < rr * rr then
        local dmg = CONTACT_DMG[e.arch]
        if dmg and (e.arch ~= "tank" or e.st == "charge") then
          hurtPlayer(world, dmg)
        end
      end
    end
  end
end

-- --- module contract -------------------------------------------------------

function combat.load(world)
  world.combat = combat
  -- player damage state; world.player.RADIUS (lib/player.lua's 5px hitbox) is
  -- the circle all enemy contact / projectiles test against
  local p = world.player
  p.hp, p.maxhp = PLAYER_HP, PLAYER_HP
  p.iframes, p.flash = 0, 0
  -- kills counter lives in world.run (B10's stats blob; combat only counts).
  -- Created here because lib/run.lua doesn't exist yet — B10 inherits it.
  world.run = world.run or {}
  world.run.kills = world.run.kills or 0
end

function combat.update(world, dt)
  local p = world.player
  p.iframes = math.max(0, p.iframes - dt)
  p.flash = math.max(0, p.flash - dt)
  -- hits still resolve after player death: bullets keep flying past a corpse
  -- (hurtPlayer no-ops on hp 0), and the kills counter keeps counting
  resolveProjectileHits(world)
  resolveContactHits(world)
end

function combat.draw() end -- damage has no draw state of its own (B8); the
-- flashes render in lib/player.lua (hurt) and lib/enemy.lua (hit) where the
-- entity sprites live, same shape as the prototype.

return combat