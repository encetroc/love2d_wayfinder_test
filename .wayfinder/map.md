## Destination

A **locked design + architecture + sequenced implementation-ticket plan** for a single-floor, top-down tiled roguelike shooter built in LÖVE 11.5 (native-only, all assets code-generated). The map **plans** — it resolves every open decision so the way to building is clear; execution runs afterward as its own small, runnable ticket series.

When this map is done: nothing left to decide. The output is a game spec, a `lib/`-module architecture, and an ordered implementation backlog where every step is small, runnable, and verifiable — built to make monolithic crash-prone code impossible.

## Notes

- **Domain**: LÖVE 11.5 game; procedural content; roguelike run structure. Consult the `/love2d` skill every session (pins 11.5, native-only, procedural; reference at `.agents/skills/love2d/REFERENCE.md`). Consult `/grilling` and `/domain-modeling` for every HITL ticket.
- **View decided**: TOP-DOWN tiled, GBC-Zelda-style ¾ overhead. NOT isometric (settled in charting; see Out of scope).
- **Standing preferences from charting** (user accepted these): plan-to-spec (no execution in the map); room-based procedural floor with permadeath + in-run upgrades; one solid floor; continuous pixel movement on a tile grid + mouse aim/click-to-shoot; one scrolling floor of connected rooms; 3 enemy archetypes (chaser / shooter / tank); health pickups + 2 weapon types with ammo + one damage/speed upgrade; procedural floor gen with **seeded RNG** for reproducible, debuggable runs.
- **Anti-crash ethos**: one subsystem per ticket, each ticket a self-contained runnable+verifiable increment; no monolithic `main.lua`; deterministic seeds for reproducibility. This is the spine of every ticket.
- **Language**: refer to tickets by their names, not bare numbers.

## Decisions so far

- **In-run progression & pickups** — pickup set: **Health +2 HP** (capped 4), **Pulse ammo +6** (cap 60), **Scatter ammo +2** (cap 16), and **one Damage upgrade +1 per run** (pulse 1→2, scatter pellet 1→2; no stacking). Weapons are NOT pickups — both owned at run start (#11 validated feel). Collect = overlap + auto-apply, caps at collect time. Seeded placement via single RNG (#2): every **non-spawn room** gets 1–2 pickups from a weighted pool (ammo/health/upgrade); upgrade guaranteed once in a room at ≥ half the floor; jitter+retry onto walkable tiles only, never corridors/walls; **spawn room gets none**. Placed-only — no enemy drops. Details: `docs/progression-pickups.md`.
- **Run lifecycle & permadeath** — a run is a 4-state FSM owned by `lib/run.lua`: START (floor generated from seed, player at `floor.spawn`) → PLAYING → CLEARED | DEAD → (R/Enter) → START. No title/menu — boots straight into a run (debug seed `"dev"` per #3). New runs: random short seed string in release, `"dev"` in debug, debug-only R replays the current seed; no user seed entry (display-only). **Spawn room always enemy-free**. **Win = walk onto the exit ladder/portal tile** in the farthest room → CLEARED; **no boss fight** (would be a 4th archetype, contradicting locked 3) and no kill requirement. **Lose = HP 0 → permadeath**, next run is a fresh seed. End states show a stats overlay (seed, kills, elapsed secs) over the frozen game; `world.run` carries that stats blob for #5's HUD. Details: `docs/run-lifecycle.md`.
- **Combat & weapon model** — two weapons: **PULSE** pistol (0.22s cd, 1 dmg, 300px/s proj r3 ~270px reach, accurate) and **SCATTER** heavy (0.55s cd, 5 pellets ×1 dmg, ±9° fan, 260px/s r2 ~91px reach — close-range burst). Identity split enforced by range: scatter reaches *shorter* than shooter keep-distance (95px), so pulse is the ranged killer. Each has its own capped ammo reserve (pulse 30/60, scatter 8/16, crates +6/+2 — real pickups → #4). Projectiles = moving circle colliders; hits = per-frame circle overlap (no hitscan; grid only blocks movement/kills projectiles on WALL). Player **4 HP** @ 130px/s, 0.5s i-frames, integer-hit damage; enemy→player: chaser contact 1, shooter proj 1, tank charge 2. Death model glue → #8. Details: `docs/combat-weapons.md`; prototype on `prototype/combat-weapons` branch.
- **Enemy AI — 3 archetypes** — awareness = same-room AND in aggro range (de-aggro otherwise, no cross-room chase); chaser 2hp/85/aggro150, shooter 3hp/60 (keep 95, fire 150, cd 1.4s, proj 165), tank 6hp/35 = area-denial **charger** (hold → 0.55s telegraph → 340px/s lunge → recover), r=9 blocks corridors; per-frame separation + wall-slide; seeded per-room spawn; HP in integer hits. Player stub NOT locked (→ #11). Details: `docs/enemy-ai.md`; prototype on `prototype/enemy-ai` branch.
- **Viewport, tile geometry & camera** — base-res Canvas rendering at **480×360** (3:2) over the 640×480 world, upscaled ×2 nearest to a **960×720** window (letterboxed); camera = centered follow + clamp + light smoothing, no aim-bias v1; config in `lib/config.lua` + `conf.lua`; debug default fixed window + seed `"dev"`. Detail: `docs/viewport-camera.md`.
- **Floor representation & seeded RNG** — floor = tile grid (WALL/FLOOR/EXIT) + room list with spawn/exit; TILE=16, map 40×30, 5-tile cell, 3–8 rooms, 1 reserved boss cell; continuous-pixel-over-grid; **full-run determinism** via `lib/seeded.lua` (layout+pickups+enemy spawns/rolls), seed as string. Detail: `docs/floor-model.md`.
- **Architecture & module decomposition** — locked the `lib/` split (14 self-contained modules, each `load/update/draw(world, dt)`), thin ordered-registration `main.lua`, shared `world` table (no cross-requires), single RNG in `lib/seeded.lua`, connectivity assert in `lib/map.lua`. Boundaries + flow only (ordering → #13). See `docs/architecture.md`.
- **Room-generation algorithm** — grid-of-rooms with connecting corridors (RogueBasin grid method), with a reserved boss/exit cell; a spanning-tree corridor pass guarantees connectivity; seeded via `love.math.random` after `setRandomSeed`. Recipe + LÖVE gotchas: `docs/research/room-generation.md`.
- **Procedural sprite & tile asset pipeline** — `ImageData:setPixel` → `newImage`; one `SpriteBatch` per tile type; `Canvas` for off-screen; neon = baked halo + `setBlendMode("add")` glow. 16×16 primitives owned by `lib/assets.lua`. See `docs/research/sprite-pipeline.md`.
- **Procedural audio scope** — `SoundData` + `newSource("static")`; minimal SFX kept; floor ambience & music **CUT**. See `docs/research/audio-scope.md`.

## Not yet specified

In-scope but not yet sharp enough to ticket. As the frontier advances these may graduate into tickets:

- **Floor size budget** (how many rooms / tile count) and difficulty ramp across the floor.
- **Camera polish** — screen shake, hit-flash, particles, juice — how much belongs in the destination vs. cut.
- Whether **gamepad** input is in scope or mouse/keyboard-only.

## Out of scope

Work consciously ruled beyond this effort. Returns only if the destination is redrawn.

- **Isometric / 2.5D projection** — the user's Q4 correction ruled this out; top-down tiled instead. This is why the map has no projection/depth-sorting ticket.
- **Meta-progression / cross-run unlocks** — single floor, no persistence between runs.
- **Multiple floors / progression beyond floor one** — the destination is one floor; more floors are a fresh effort.
- **External libraries, vendored code, committed art/audio asset files** — `/love2d` is native-only, procedural-everything.
- **Network / multiplayer**.
