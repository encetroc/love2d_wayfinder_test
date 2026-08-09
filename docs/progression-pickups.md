# In-run progression & pickups

> Decision from wayfinder ticket **#4** (grilling, HITL, user-approved — all five frontier questions answered). Pins the pickup set, seeded placement, collect rule, and each effect on player/combat state. All within a single run — no meta-progression (map out-of-scope).

## The pickup set

| Pickup | Effect | Cap / notes |
| --- | --- | --- |
| **Health** | +2 HP on collect | capped at player max (4 HP, #11); can't overheal |
| **Pulse ammo** | +6 pulse reserve | capped at weapon max (60, #11) |
| **Scatter ammo** | +2 scatter reserve | capped at weapon max (16, #11) |
| **Damage upgrade** | +1 damage (pulse 1→2, each scatter pellet 1→2) | exactly **one per run**, no stacking |

Weapons themselves are **not** pickups — the player owns both PULSE and SCATTER from run start (#11's playtested, approved feel). Ammo scarcity + the upgrade carry the run's progression.

## Collect rule

- **Overlap + auto-collect** (no key, same as the #11 prototype) — walking over a pickup applies its effect immediately.
- Caps enforced at collect time (ammo caps, health max); nothing is "reserved" or marked for later.

## Seeded placement

- Flows through the single RNG in `lib/seeded.lua` (#2): **layout + pickups + enemy spawns/rolls** — identical seed ⇒ identical pickup layout.
- Every **non-spawn room** gets **1–2 seeded pickups** drawn from a weighted pool: pulse ammo / scatter ammo / health / upgrade.
- **Upgrade spawn is guaranteed once per run**, placed in a room at ≥ half the floor (mid-run power moment).
- Placement jitter + retry onto walkable floor tiles (same pattern as enemy spawns, #6); **never in corridors, never on walls**.
- The **spawn room gets no pickups** — it's enemy-free (#8), so a free heal/ammo there would be dead value.

## Why these numbers

- **+2 health** (half of a 4-HP bar): meaningful against chaser contact (1) and shooter bullets (1); +1 would be nearly invisible.
- **+6/+2 ammo**: the exact amounts playtested and approved in #11. Scatter stays tight (2 shells ≈ 1.1 s of fire ≈ one close-quarters trade).
- **Damage +1**: the real lever in an integer-hit economy — pulse becomes chaser 1-shot / shooter 2-shot / tank 3-shot; scatter point-blank 10 dmg wrecks the tank. That is the run's speed-up payoff toward its far end.
- **Placed-only, no enemy drops**: drops would add supply reliability that weakens the scarcity loop and permadeath's bite. A future tuning pass could revisit.

## Where it lives

- `lib/pickups.lua` (per #9's split): pickup defs/effects, seeded placement, overlap collect — read from `world.run`/`world.player` inside `PLAYING` state (#8).
- Pickup sprites graduate from #7's primitive pipeline (16×16, neon palette; a pickup needs its own sprite family — build-time detail for #13).
- HUD readout of held upgrades/ammo → #5's domain.
