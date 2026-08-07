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

- **Room-generation algorithm** — grid-of-rooms with connecting corridors (RogueBasin grid method), with a reserved boss/exit cell; a spanning-tree corridor pass guarantees connectivity; seeded via `love.math.random` after `setRandomSeed`. Recipe + LÖVE gotchas: `docs/research/room-generation.md`.
- **Procedural sprite & tile asset pipeline** — `ImageData:setPixel` → `newImage`; one `SpriteBatch` per tile type; `Canvas` for off-screen; neon = baked halo + `setBlendMode("add")` glow. 16×16 primitives owned by `lib/assets.lua`. See `docs/research/sprite-pipeline.md`.
- **Procedural audio scope** — `SoundData` + `newSource("static")`; minimal SFX kept; floor ambience & music **CUT**. See `docs/research/audio-scope.md`.

## Not yet specified

In-scope but not yet sharp enough to ticket. As the frontier advances these may graduate into tickets:

- Exact **boss/exit room content** — we chose "one exit/boss room" at floor's end; what actually lives there (a boss? a door? a ladder?) is unspecified.
- The **two weapon identities** (names, fire pattern, feel) and exact tuning numbers (damage, fire rate, enemy HP/speed) — real values get fixed when the combat model is prototyped.
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
