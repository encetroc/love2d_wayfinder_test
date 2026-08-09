# Wayfinder — single-floor roguelike shooter domain

Terms locked by the map's resolved tickets (#2 floor, #6 enemy AI, #8 run lifecycle, #9 architecture, #11 combat). Glossary only — implementation lives in `docs/` and the `lib/` plan.

## Run structure

**Run**:
A single play of the floor, from seed to win-or-death. The atomic unit of the game; no persistence between runs.
_Avoid_: level, stage, round, attempt

**Floor**:
The one fully-procedural level of the game — a tile grid plus a room list with a spawn room and a farthest exit room.
_Avoid_: level, map, dungeon (map is the planning artifact, not the in-game floor)

**Room**:
A rectangular, wall-bounded area of the floor, from the room list; awareness and spawns are scoped per-room.
_Avoid_: section, chamber

**Seed**:
The string that deterministically produces a run — identical seed ⇒ identical run. Display-only; debug fixes it to "dev".
_Avoid_: random seed number

**Spawn room**:
The room the player starts in; always enemy-free.
_Avoid_: start room (only when the emphasis is on position, not safety)

**Exit**:
The walkable ladder/portal tile in the farthest room; touching it clears the run (win). There is no boss enemy.
_Avoid_: boss room, door, goal

**Cleared**:
The win state of the run — achieved by walking onto the exit tile. Equivalent to beating the game (single-floor destination).
_Avoid_: victory (screen text only), finished

**Permadeath**:
The loss state of the run — HP 0 ends the run permanently; the next run is a fresh seed.
_Avoid_: death (as a mechanic, not the visual state), game over

## Enemies (3 archetypes, locked)

**Chaser**:
The pursuit archetype — fast melee triangle, 2 HP, damages on contact.
_Avoid_: runner, melee

**Shooter**:
The ranged keep-away archetype — square, 3 HP, backs off and fires projectiles at range.
_Avoid_: ranged, gunner

**Tank**:
The area-denial charger archetype — hexagon, 6 HP, blocks corridors and telegraphs a 2-damage charge.
_Avoid_: boss, heavy, bruser

## Combat

**Pulse**:
The pistol weapon — fast, accurate, single-projectile, 1 damage, the ranged killer.
_Avoid_: pistol, gun

**Scatter**:
The heavy weapon — a 5-pellet close-range burst, weaker past the shooter's keep-distance.
_Avoid_: shotgun, heavy, spray

**HP**:
Hit points, measured in integer hits; 4 for the player, 2/3/6 for chaser/shooter/tank.
_Avoid_: health (health is a general concept; HP is the game's model)

## Pickups

**Pickup**:
A collect-on-overlap item placed in a room floor, part of in-run progression. Weapons are never pickups.
_Avoid_: item, collectable, crate (crates were the prototype stand-in)

**Health pickup**:
A pickup that restores +2 HP, capped at the 4-HP maximum.
_Avoid_: medkit, heart

**Ammo pickup**:
A pickup that restores +6 pulse or +2 scatter reserve ammo, capped at the weapon's max.
_Avoid_: ammo crate, clip

**Damage upgrade**:
The single per-run pickup (spawned once, mid-floor) that raises damage by +1 on both weapons.
_Avoid_: power-up, buff
