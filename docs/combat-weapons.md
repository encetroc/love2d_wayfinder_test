# Combat & weapon model

> Decision from wayfinder ticket **#11** (prototype, HITL, user-approved after playtest). Pins the two weapon identities + tuning numbers, ammo handling, projectile representation, hit detection, and the damage flow (including player HP and enemy→player damage). Primary source prototype at `prototypes/combat-weapons/` (branch `prototype/combat-weapons`).

## The two weapons (identities + feel)

| | **PULSE** (pistol) | **SCATTER** (heavy) |
| --- | --- | --- |
| Role | fast single-shot, accurate | close-range burst |
| Fire pattern | 1 projectile straight down the aim line | 5 pellets in a ±9° fan (deterministic steps + small jitter) |
| Cooldown | 0.22 s (~4.5/s) | 0.55 s |
| Damage | 1 | 5 × 1 (pellets resolve independently) |
| Projectile | 300 px/s, r=3, life 0.9 (~270 px reach) | 260 px/s, r=2, life 0.35 (~91 px reach) |
| Ammo | start 30 / cap 60, crates +6 | start 8 / cap 16, crates +2 |

The **identity split** is enforced by range, not just fire rate: scatter's reach (~91 px) is *shorter* than the shooter's keep-distance (95 px), so the shotgun cannot snipe — pulse is the ranged killer (and the shooter/keep-away answer), scatter is the close-quarters burst that punishes chasers and tank charges. Against the locked #6 enemy HP: pulse = 2/3/6 hits (chaser/shooter/tank); scatter point-blank = 1 blast kills chaser, 2 blasts kills tank, partial hits at mid range.

## Ammo handling

- Each weapon has its own **reserve** (`ammo`), capped (`max`); firing consumes 1 per trigger pull (pellets are one pull, not one-per-pellet).
- Empty weapon simply won't fire — no reload, no jam; swap away (`1`/`2`) or find ammo.
- Ammo arrives from **crates** in the prototype (collect on overlap, +6 pulse / +2 scatter, capped) — this is a stand-in; the real pickup set/placement/effects are ticket **#4**'s domain.

## Projectile representation

- Projectiles are **moving sprites with circle colliders**: `{x, y, vx, vy, r, life, from, dmg, col}` advanced per-frame in `update`; die on `life <= 0`, WALL tile, or a hit.
- Tinted per origin (player shot vs enemy projectile); pulse pellets are tiny bright circles (r=2–3), same rendering pipeline as #7's primitive set.

## Hit detection (the "how are hits detected" answer)

- **Circle-overlap entity bounds, checked per frame** — projectile-vs-enemy and projectile-vs-player use squared-radius overlap `d² < (r1+r2)²`.
- **Contact damage** for chasers (touch) and the tank (charge state only — tank is harmless while holding/recovering) uses the same circle test against the player.
- The **tile grid is not a hitscan layer**: it only blocks movement (wall-slide) and kills projectiles on WALL tiles. No ray-casting, no grid-cell hit tests — consistent with the #6 prototype's validated feel.
- Friendly fire off: player projectiles only hit enemies, enemy projectiles only hit the player.

## Damage flow & player model (this ticket's domain)

- **HP in integer hits** (same ethos as #6). Enemy HP is already locked (#6: chaser 2 / shooter 3 / tank 6); this ticket locks the player side.
- **Player: 4 HP**, 130 px/s, r=6.
- **Enemy→player damage: chaser contact 1, shooter projectile 1, tank charge 2** (the charge is half your bar — the 0.55 s telegraph is the counterplay).
- **0.5 s i-frames** after any hit (prevents stun-lock from chaser swarms and multi-hit from one charge), red hurt flash; enemies keep the 0.12 s white hit-flash from #6.
- Death = a `PERMADEATH` overlay with restart — the full run lifecycle/permadeath glue is ticket **#8**'s domain; #8 reads this health/damage model.

## Where it lives

- Player + movement + weapon switching → `lib/player.lua`; weapon defs/fire → `lib/weapons.lua`; projectiles → `lib/projectiles.lua`; damage/hits/HP/death → `lib/combat.lua` (per #9's module split).
- Camera follow (used to iterate the feel at #3's viewport) stays in `lib/camera.lua`; HUD readouts (HP/ammo/weapon) are minimal prototypes and graduate in #5.
- Ammo crates are a prototype stand-in; real pickup effects live in `lib/pickups.lua` (#4).
