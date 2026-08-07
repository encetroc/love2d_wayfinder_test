# Architecture & module decomposition

> Decision from wayfinder ticket **#9** (grilling, HITL, approved by the user). Fixes the `lib/` module boundaries and the `load/update/draw` flow for the single-floor top-down tiled roguelike shooter. Does **not** fix implementation ordering (that is `#13` backlog-sequencing).

## Goal

No single file becomes an unmaintainable monolith — the repo's core "avoid large crash-prone code / no monolithic `main.lua`" ethos. Each subsystem is a self-contained module; every module is one runnable, verifiable increment.

## Module list

```text
main.lua         thin: build world, register modules (ordered), drive load/update/draw(world, dt)
lib/seeded.lua   single RNG: setSeed / rand / int / pick   (deterministic spine)
lib/assets.lua   procedural gen: tiles, sprites, sfx SoundData  (built once)
lib/map.lua      floor gen (grid-of-rooms) + tile grid + rooms + connectivity assert
lib/player.lua   position, health, movement, input→motion
lib/weapons.lua  two weapon defs, fire pattern, ammo
lib/projectiles.lua  projectile motion + collision vs enemies
lib/enemy.lua    3 archetypes + AI + spawning
lib/combat.lua   small coordinator: damage/hits, HP, death, hit-flash
lib/pickups.lua  health/ammo/upgrade pickups + collect
lib/run.lua      run lifecycle: enter-room / exit / boss / permadeath
lib/camera.lua   viewport follow + shake
lib/hud.lua      draw health/ammo/upgrades
lib/audio.lua    sfx playback + one-shot source pool
```

## Working rules

1. **Self-contained modules**: every module exposes `load / update / draw`, each taking `(world, dt)`. No cross-module `require`.
2. **Shared `world` table**: `main` builds one `world` (holding player, map, enemies, run, …) and passes it into each module's hooks. Modules read/write `world`, but never `require` each other. This gives loose coupling + a deterministic, auditable update order.
3. **Thin `main.lua`**: holds an *ordered registration list* of modules and calls each one's hooks in sequence. New modules slot in with one line.
4. **Determinism / fail-loud**: the single RNG lives in `lib/seeded.lua`, seeded once at run start. `lib/map.lua` runs the connectivity assert after floor gen. Both checked in `love.load`, failing loudly in dev — no silent randomness.
5. **Ownership**: this ticket fixes boundaries + flow only. Implementation *ordering* is `#13` backlog-sequencing.

## Decisions feeding this (from research)

- `lib/assets.lua` owns procedural generation per **#7** (ImageData:setPixel → newImage, SpriteBatch, Canvas, additive-glow) and sfx SoundData per **#10**.
- `lib/map.lua` uses the grid-of-rooms-with-corridors algorithm per **#12**, seeded via `love.math.random` after `setRandomSeed`.
