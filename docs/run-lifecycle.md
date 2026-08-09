# Run lifecycle & permadeath

> Decision from wayfinder ticket **#8** (grilling, HITL, user-approved — all six frontier questions answered). Pins how a single run starts, progresses, and ends, and the state machine that glues the floor (#2), combat (#11), and enemies (#6) into the loop. This is the sequence/module layer that keeps `main.lua` thin (#9's `lib/run.lua`).

## The run state machine

A run is a **tiny FSM with four states**, owned by `lib/run.lua` (per #9's module list: "run lifecycle: enter-room / exit / boss / permadeath"):

```text
START ──(floor generated from seed; player placed at floor.spawn)──▶ PLAYING
PLAYING ──(touch exit tile)──▶ CLEARED
PLAYING ──(hp 0, permadeath)──▶ DEAD
CLEARED │ DEAD ──(R / Enter: new run)──▶ START
```

- **START**: generate the floor from the run seed, spawn the player at `floor.spawn`. No title/menu in v1 — the game boots **directly into** a run (debug: seed `"dev"` per #3, so every fresh boot renders identically).
- **PLAYING**: normal loop — movement, combat, enemies, pickups. The only state where the player has control.
- **CLEARED**: the win state.
- **DEAD**: the permadeath state.
- Both end states show a **full-screen result overlay over the frozen game** (stats: seed, kills, elapsed secs), and **R or Enter starts a new run**. No auto-restart — the seed/stats are visible before they're lost.

`lib/run.lua` owns the state + the per-run stats blob; it is the only module that reads/writes run state. `main.lua` stays thin (ordered registration per #9).

## How a new run is seeded

- **Release**: each new run draws a **random short seed string** (4–6 chars from `love.math.random` passes through the single RNG in `lib/seeded.lua`, #2).
- **Debug**: new runs default to seed **`"dev"`** (per #3) unless a seed is supplied; and a **debug-only replay key** (R) restarts the *current* seed for reproducible debugging — the same `R`-regenerate behavior validated in the #6 and #11 prototypes.
- No user seed entry in v1 — the seed is **display-only** (surfaced on end screens; live HUD readout later in #5).
- Determinism spine from #2 unchanged: layout + pickups + enemy spawns/rolls all flow through the one seeded RNG; identical seed ⇒ identical run.

## Spawn room safety

The **spawn room is always enemy-free**: rooms get their seeded enemy budgets round-robin per #6, with the spawn room excluded. The player gets a breath before threat; walking into a corridor or adjacent room still triggers awareness (same-room + aggro, #6). Cost is one room excluded at spawn-time.

## Win condition — the exit (graduates the map's last fog item)

- The farthest room (reserved boss/exit cell, #2/#12) contains an **exit portal/ladder** (the `EXIT` tile).
- **Win = walk onto the exit tile** → `CLEARED`. No interaction key, no kill requirement, **no boss fight** — adding a boss would be a 4th enemy archetype, contradicting the locked 3-archetype set (#6).
- Enemies in the exit room are still a gauntlet (seeded per-room as usual), but clearing them is not required — the run can be won by reaching the ladder.

## Loss condition — permadeath

- **HP 0 → `DEAD`** (player hp from #11: 4 HP, i-frames 0.5s; enemy→player: chaser 1, shooter 1, tank charge 2).
- Full restart: the **next run is a new run** — new seed per the seeding rule above (debug: `"dev"`). No continuing, no recovery.
- The death overlay stub from the #11 prototype graduates into the `DEAD` state's result screen.

## Per-run stats

`world.run` carries a minimal stats blob: **seed (string), kills, elapsed secs**. Shown on both end screens; live HUD readout is #5's domain. Nothing else — no scores, no cross-run persistence (meta-progression is out of scope per the map).

## What this unblocks

- **#4 In-run progression & pickups** — readies the pickup/collect flow inside `PLAYING`.
- **#5 HUD & game feel** — live HUD (HP/ammo/seed/kills) draws from `world.run`; end-screen juice.
- **#13 Implementation backlog** — the run FSM is the sequencing spine; every subsequent build ticket slots into a run state.
