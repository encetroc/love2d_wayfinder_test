# Floor representation & seeded RNG

> Decision from wayfinder ticket **#2** (grilling, HITL, user-approved). Pins the data model for one floor and how the deterministic seed flows through it. Complements `docs/architecture.md` (#9) and the room-gen research (#12).

## Floor object shape

A floor has two complementary halves — a **tile grid** for geometry, and a **room list** for logic.

```text
floor.grid      -- 2D array [ty][tx] of tile kinds: WALL | FLOOR | EXIT
floor.rooms     -- list of rooms: { id, rect={x,y,w,h}(tiles), connections={id,...}, spawn?, exit? }
floor.spawn     -- { room, tx, ty }   the designated root room / start tile
floor.exit      -- { room, tx, ty, boss=true }  the reserved farthest cell
```

- `map:isWalkable(tx,ty)` → bool (FLOOR/EXIT walkable; WALL not).
- `map:tileAt(x,y)` → tile kind from pixel coords.
- room lookup by position → "which room am I in" for `run`/`enemy`/`player`.

Map-gen, combat, and enemies all read from this one object; nothing re-derives layout.

## Fixed dimensions (graduates the "floor size budget" fog item)

| Constant | Value |
| --- | --- |
| `TILE` | **16 px** |
| Map size | **40×30 tiles** (= 640×480 world px) |
| Grid cell | **5 tiles** → 8×6 = 48 candidate cells |
| Room count | 3–8 |
| Exit/boss | 1 reserved farthest cell |

## Continuous pixel world over discrete grid

- **Movement/collision model:** player and enemies move in continuous pixels; the tile grid is the discrete obstruction layer.
- World pixel coords ↔ tile coords via `TILE` constant + helpers (`x / TILE`, `tx * TILE`). Collision checks the grid; rendering uses pixel coords.

## Seeded RNG (in `lib/seeded.lua`)

- **Full-run determinism:** the run seed is set once at run start (`setSeed`); *every* random draw in the run flows through it — floor layout, pickup placement, enemy spawns, and enemy AI rolls. Identical seed ⇒ identical run, for debugging.
- Wrapper API: `setSeed / rand / int / pick` around `love.math.random` (never Lua `math.random`, never `love.math.noise` for layout).
- Seed exposed as a string (hashed via `love.data` for a memorable input), surfaced in the HUD later.

## What the seed controls

1. Floor layout (rooms, corridors, connectivity — from #12 recipe).
2. Pickup placement.
3. Enemy spawn placement + spawn-time rolls.

## Boundary

This ticket fixes the **data model + seed flow + spawn/exit placement only**. The *how* of enemy spawn distribution (per-room counts, aggro) is ticket **#6 enemy-AI**'s job — this guarantees enemies can read room/spawn info from the floor.
