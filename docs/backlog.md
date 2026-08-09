# Implementation backlog — sequenced build tickets

> Decision/output of wayfinder ticket **#13** (task). The map's final artifact: the ordered, runnable, verifiable build sequence that executes the locked plan. Each ticket is one subsystem, small enough for a single session, leaving the game runnable at every step — no big-bang integration, no monolithic `main.lua` (#1 anti-crash ethos). Constraints backported from #9 (14-module `lib/` split, thin ordered-registration `main.lua`, shared `world`, no cross-requires, single RNG, connectivity assert), #3 (debug seed `"dev"`, 960×720 window), #2 (determinism), #8 (run FSM), and both prototypes as reference implementations.

## Build order (12 tickets)

Each ticket: **module(s)** → what's built → **verify by** (all via `./run-game.sh`, seed `"dev"`).

| # | Ticket | Modules | Verifiable increment |
| --- | --- | --- | --- |
| **B1** | Shell & viewport boot | `conf.lua`, `lib/config.lua`, `main.lua` skeleton | Window opens 960×720; base-res canvas 480×360 upscaled ×2 nearest; letterbox on resize; module contract (`load/update/draw(world, dt)`) with a stub world; registration list in `main.lua` = the thin-spine shape. |
| **B2** | Seeded RNG spine | `lib/seeded.lua` | `setSeed/rand/int/pick` over `love.math.random`; string seed hashed via `love.data`; never `math.random`. Debug screen prints first N draws → identical across restarts with `"dev"`, different with another seed. |
| **B3** | Procedural assets | `lib/assets.lua` | #7 pipeline: 16×16 floor/wall/player/3-enemy/projectile/glow/particle primitives + #10 SFX `SoundData` (shoot, enemy-hit/death, pickup, hurt/player-death). Verify: on-screen test strip renders each primitive; built once, reused (no per-frame gen). |
| **B4** | Floor generation | `lib/map.lua` | Grid-of-rooms + corridors (spanning-tree connectivity), reserved farthest EXIT cell, `isWalkable/tileAt/roomAt`, connectivity **assert**; spawn room marked. Verify: floor renders from `"dev"`; assert passes; two seeds differ; identical re-render on R. |
| **B5** | Player movement & camera | `lib/player.lua`, `lib/camera.lua` | Continuous-pixel movement + grid wall-slide; centered follow + clamp + smoothing (#3). Verify: traverse the whole floor, slide along walls, camera never shows past 640×480 edges. |
| **B6** | Shooting: weapons + projectiles | `lib/weapons.lua`, `lib/projectiles.lua` | PULSE/SCATTER defs & fire pattern (#11), per-weapon capped ammo, projectile motion + wall-death + life (no enemy collision yet). Spread-aware spawn (scatter fan). Verify: fire both, ammo decrements, projectiles die on walls, scatter spreads. |
| **B6.1** | Antecrypt visual style pass (ticket #26) | existing `lib/assets.lua` + draw paths; no new modules | Rebuild the look to match **Antecrypt** (PUNKCAKE): near-black + dark-green-on-black world, bright-green entities, white "hard-drive" monolith / glow accents, additive laser tracers + explosion bursts, scanline row texture + corner vignette, bright pixel-font HUD in top/bottom bars. Style ONLY — all mechanics/numbers stay locked; assets stay code-generated (rule 5). Sources: Steam screenshots + intro GIF (see ticket #26; local captures in /tmp/antecrypt_style). Verify: eyeball vs screenshots + pixel-metric smoke (frames >30% black, entity greens in the #35aa5a family, accents red/white). |
| **B7** | Enemy AI | `lib/enemy.lua` | 3 archetypes verbatim (#6): same-room+aggro awareness/de-aggro, chaser seek, shooter keep-band + fire, tank hold→windup→charge→recover, separation, wall-slide, per-room seeded spawn (spawn room excluded per #8). Shooter fires #6's 165px/s projectile (motion only). Verify: chaser pursues/de-aggros across rooms; tank telegraphs + charges; 2 seeds spawn differently. |
| **B8** | Combat & damage flow | `lib/combat.lua` | Projectile-vs-enemy + contact-vs-player circle collision (no hitscan), HP in integer hits (#11), 0.12s enemy hit-flash + 0.25s player hurt flash, 0.5s i-frames, kills counter into `world.run`. Verify: chaser dies in 2 pulse hits / 1 scatter blast; tank charge costs 2 HP + i-frames prevent chain damage; player death sets HP 0. |
| **B9** | Pickups | `lib/pickups.lua` | Seeded 1–2 per non-spawn room (weighted pool), upgrade once ≥ half-floor, jitter+retry onto walkable tiles, never corridors/walls; overlap auto-collect; effects #4: +2 HP (cap 4), +6 pulse/+2 scatter (caps), damage +1. Verify: collect each type; caps enforced; identical layout on same seed. |
| **B10** | Run lifecycle | `lib/run.lua` | #8 FSM `START→PLAYING→CLEARED\|DEAD→START`; random short seed string on new run (debug `"dev"`, debug R replays current seed); spawn at `floor.spawn`; win = walk onto exit ladder; permadeath on HP 0; end overlays + stats (seed/kills/time); `world.run` stats blob. Verify: boot→play→exit = CLEARED w/ stats; die = DEAD; R restarts same seed; new run reseeds. |
| **B11** | Audio | `lib/audio.lua` | One-shot source pool + playback hooks: shoot (weapons), enemy-hit/death + pickup (combat/pickups), hurt/player-death (combat). Verify: each event plays its SFX; pool reuses sources; no per-frame allocation. |
| **B12** | HUD & game feel | `lib/hud.lua`, camera shake | #5: top-left HP pips + both weapons' ammo (active bright/inactive dimmed) + upgrade marker; bottom stats line `seed · room · kills · time`; spread-aware reticle (pulse crosshair / scatter ±9°+reach arc); room-entry toast; 2–4px shake on hurt + tank charge impact; enemy-death + pickup particle pops. Verify: all readouts live; reticle switches with weapon; toast fires on room entry; shake on hits. |

## Ordering rationale

- **B6.1 sits between B6 and B7**: a pure visual-retheme pass (no new modules, no mechanics) so the look is settled before B7 clothes the enemies in the same style; B7 is natively blocked by B6.1. The frontier query surfaces exactly one buildable ticket (currently B6.1).

- **Determinism first**: B2 (RNG) precedes everything random (B4/B7/B9), so every later ticket's verify step is reproducible.
- **The game is runnable after every ticket**: B1 boot → B2 dev readout → B3 test strip → B4 renders a floor → B5 walk it → B6 shoot → B7 fight AI → B8 kill/die → B9 loot → B10 full loop → B11 sound → B12 feel. Each step extends the previous working state; the only "integration" is one registration line in `main.lua`.
- **Combat before run**: B8's HP/death is what B10's DEAD state reads; B9's effects need B8's HP + B6's ammo.
- **Motion before damage**: B6 moves projectiles, B7 moves enemies, B8 resolves hits — collision resolution is one module's job, added after both movers exist (shooter's bullet is motion-only until B8).
- **Audio/HUD last**: they only read state every earlier ticket produced; B12 depends on B6 (reticle), B8 (shake/flash), B9 (pickup pop), B10 (stats, toast).

## Hard rules each ticket obeys (backported from #9/#2/#3)

1. One subsystem per ticket; module exposes `load/update/draw(world, dt)`; no cross-module `require` — all communication via the shared `world` table.
2. `main.lua` stays thin: ordered registration list only; new module = one line.
3. Every random draw flows through `lib/seeded.lua`; identical seed ⇒ identical run; debug default seed `"dev"`.
4. `lib/map.lua` connectivity assert runs in `love.load`, fail-loud.
5. Assets/SFX generated once (`lib/assets.lua`), never rebuilt per frame; no asset files ever.
6. Prototypes (`prototype/enemy-ai`, `prototype/combat-weapons`) are the reference implementations — port, don't redesign.

## Scope notes

- **Gamepad: OUT of v1.** Standing preference is mouse aim/click-to-shoot (keyboard + mouse) — the reticle, click-fire, and 1/2 weapon-swap are all mouse/keyboard idioms (#11, #5). Gamepad would need aim-retargeting, bindings UI, and input mapping — real scope, no ticket claims it. The final fog item on the map; resolves to mouse/keyboard-only unless the destination is redrawn. (Previously a "Not yet specified" item; all others graduated in #2/#4/#5.)
- Debug-only keys (R replay seed, G always-aggro) are dev helpers, not shipped UX; B10 owns R per #8.
- Each ticket ships with its verify procedure; a run's seed is always shown on-screen from B10 (HUD earlier shows it in debug text) so reproduction is copy-pasteable.
