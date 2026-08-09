# HUD & game feel

> Decision from wayfinder ticket **#5** (grilling, HITL, user-approved — all four frontier questions answered). Pins the HUD readouts + placement and the game-feel in/cut list for the single-floor scope. All per-run, nothing cross-run (map out-of-scope). Renders from locked state: HP/weapons/ammo (#11), `world.run` stats (#8), damage-upgrade marker (#4), room structure (#2/#8).

## HUD layout (two-corner minimal)

Drawn by `lib/hud.lua` (#9) in screen space over the #3 viewport, at base res (480×360), scaled with the rest:

**Top-left stack** (always visible):

1. **HP pips** — 4 pips, filled = HP (green, same as #6/#11 palette).
2. **Active weapon name + reserve** — `PULSE n/60` or `SCATTER n/16`; the inactive weapon is shown dimmed but **always visible** (both weapons' ammo on screen — playtested in #11; hiding the inactive one saves pixels but costs swap-planning value).
3. **Damage-upgrade marker** — small indicator (colored chevron/dot) shown once the #4 upgrade is owned; no text bloat.

**Bottom-left stats line** (small, muted): `seed · room · kills · time` — the `world.run` blob (#8: seed string, kills, elapsed secs) plus the current room number. One line, no busy HUD.

Readouts the ticket mentioned but we deliberately do **not** add: objective text, minimap, XP bar (single-floor run doesn't need them).

## Aim reticle (spread-aware, mouse aim)

- Pulse equipped: **tight 4-tick crosshair** at the cursor.
- Scatter equipped: the reticle renders the **±9° fan + ~91px reach** of the scatter cone (short arc / double-arrow), telegraphing #11's range-split identity at a glance — no text.
- No aim line from the player (prototype artifact; tested, clutters).

## Game-feel scope (in vs. cut)

**Carried as already locked** (no change): enemy 0.12s hit-flash (#6), player red hurt flash + 0.5s i-frame blink (#11), muzzle flash (#11), tank pulsing telegraph + direction line (#6).

**In (small, procedural, all through #7's primitive pipeline):**

| Juice | Rule |
| --- | --- |
| **Screen shake** | 2–4 px, decaying, on **player hurt** and **tank charge impact** only — `lib/camera.lua` keeps its "follow + shake" boundary from #9 (shake was deferred in #3, now graduated at minimal scope). |
| **Death burst** | small additive glow-particle pop on each enemy death (feedback beyond the HP-pip bar). |
| **Pickup collect-pop** | one small sparkling pop when a pickup is collected (pickups keep their idle pulse). |

**Cut** (legibility + scope): ambient floor particles, projectile trails, hit-stop / freeze frames, screen edge flash, per-camera aim bias (#3's "deferred juice" stays deferred).

## Room indicator (entry toast)

- On **room entry** (crossing into a new room — the `run` enter-room event, #8): a brief fading **toast** `ROOM n` (~1.5 s, no persistent readout).
- Doubles as visible confirmation of #8's enemy-free spawn room ("did I leave the spawn room yet?").
- No persistent room UI; rooms are visually self-explanatory once inside.

## Where it lives

- `lib/hud.lua`: HUD readouts (top-left stack, bottom stats line) + reticle + room toast.
- `lib/camera.lua`: shake (2–4 px decay), per #9's module boundary.
- Particles: `love.graphics.setBlendMode("add")` glow pops via #7's `particle1`/`glow` primitives — generated assets only, no files.
- End-screen overlays (CLEARED/DEAD with seed/kills/time) already locked in #8 — static, no extra juice.
