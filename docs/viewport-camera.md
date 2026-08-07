# Viewport, tile geometry & camera

> Decision from wayfinder ticket **#3** (grilling, HITL, user-approved). Pins the screen/window policy and camera model for the top-down tiled view. Complements `docs/floor-model.md` (#2) and `docs/architecture.md` (#9, `lib/camera.lua`).

## Viewport & geometry

| Constant | Value |
| --- | --- |
| `TILE` | **16 px** (from #2) |
| World size | **640×480** px (40×30 tiles, from #2) |
| **Viewport base res** | **480×360** (3:2) |
| Default window | **960×720** (= viewport ×2) |

The viewport (480×360) is smaller than the world (640×480), so the camera scrolls to reveal the floor. Camera scroll range: x ∈ [0, 640−480=160], y ∈ [0, 480−360=120].

## Window scaling

- Render the world into a **Canvas at base res (480×360)**, then draw that canvas **scaled up ×2 with nearest-neighbor** (pixel-crisp for the flat/neon style) to the 960×720 default window.
- **Letterboxed + responsive to resize**: keep the 3:2 aspect, pad with background when the window aspect differs.
- `conf.lua` (LÖVE's) sets the window; `love.window.setMode`.

## Camera model

- **Centered follow**: camera tracks the player's center each frame.
- **Clamp to world bounds** — never shows past the 640×480 edge.
- **Light smoothing** so it eases instead of teleporting.
- **No aim-biasing in v1** — keep it dead simple; biasing toward the mouse is deferred juice if the feel asks later.
- Screen-shake is a later polish item, not part of this base.

## Config home

- **`lib/config.lua`** — single constants table read by downstream render + gameplay modules: `TILE`, `MAPW`, `MAPH`, `VIEW_W`, `VIEW_H`, window constants.
- **`conf.lua`** — LÖVE's window configuration (`love.window.setMode`, 960×720 default).

## Seed-friendly debug default

- Default to a **fixed window** (960×720), **fullscreen off in dev**.
- **Default run seed `"dev"`** when none is given → the first run renders identically on every restart (reproducible-runs ethos from #2).
