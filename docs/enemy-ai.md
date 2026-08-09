# Enemy AI — 3 archetypes

> Decision from wayfinder ticket **#6** (prototype, HITL, user-approved after playtest v2). Framework + numbers locked from the prototype at `prototypes/enemy-ai/` (primary source on branch `prototype/enemy-ai`).

## Awareness model (the gating rule)

An enemy is **aware** of the player only when **both** hold:

1. the player is in the **same room** as the enemy (room membership from the floor's room list, #2), **and**
2. the player is within the enemy's **aggro range**.

If either fails, the enemy **de-aggros**: stops moving and resets to idle. This is what prevents cross-room chasing (fixes the shooter hugging walls into the next room). Aggro is re-evaluated every frame.

## Archetype table (locked numbers)

| Archetype | Role | HP (hits) | Speed | Aggro | Details |
| --- | --- | --- | --- | --- | --- |
| **chaser** | pure pursuit | 2 | 85 px/s | 150 | triangle body (r=6); seeks player when aware |
| **shooter** | ranged keep-away | 3 | 60 px/s | 170 | backs off < 95, approaches > 150, holds + fires in band; fire cooldown 1.4 s; projectile 165 px/s, r=2.5 |
| **tank** | area-denial charger | 6 | nudge 35 px/s | 120 | r=9 (blocks corridors); state machine: **hold** (keeps 50–95) → **wind-up** (0.55 s, pulsing telegraph + direction line) → **charge** (340 px/s for 0.4 s at locked direction) → **recover** (0.9 s) |

## Shared framework

- **Separation**: per-frame push apart when `r1 + r2 + 4` overlap; stops enemies stacking, lets tanks body-block corridors.
- **Wall-slide collision**: axis-separated movement against the tile grid; enemies slide along walls instead of sticking.
- **Spawning**: per-room, seeded — round-robin across rooms, jitter with retry onto walkable tiles, room membership recorded at spawn.
- **HP in integer hits** + hit-flash (0.12 s) on damage; death at 0 HP. Painful-but-fair pacing was validated at chaser 2 / shooter 3 / tank 6 hits.

## Not locked here (belongs to #11)

The prototype's player is a stub (120 px/s, shot 260 px/s, 1 dmg). Real weapon identities, damage, player HP and enemy→player damage are **#11 combat & weapon model**'s domain — and #8 run-lifecycle reads the resulting health/death model.
