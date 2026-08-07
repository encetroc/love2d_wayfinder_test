---
name: love2d
description: Build LÖVE (Love2D) games in Lua against version 11.5, native-only — every asset generated in code, no external libraries, helpers written as local libs. Use for any LÖVE game code: the main loop, drawing, procedural images/audio/fonts, input, physics, or movement/AI math.
---

# LÖVE (Love2D) 11.5

LÖVE is a Lua game framework: a single `main.lua` declares the **callbacks** LÖVE calls every frame, and everything else — drawing, input, sound, physics — is the `love.*` module API. This skill pins the version (11.5), locks the project's standing rules, and carries the API reference behind a pointer.

## Rules (non-negotiable, every session)

1. **Version 11.5.** Follow 11.5 behaviour exactly: colors and mesh vertex colors are **0..1 floats** (not 0..255); angles are **radians**; the origin is the **top-left** with **x→right, y→down**.
2. **Native-only.** Use only the LÖVE API (`love.*` modules). No external libraries, no vendored C, no `require` of anything outside the project.
3. **Procedural everything.** Every asset — images, audio, fonts — is **generated in code at runtime**, never loaded from a committed asset file. There are no art/audio asset files in this repo, and one is never added.
4. **Local libs.** When a helper or library is genuinely needed, **write it yourself** under `lib/` as project code using only `love.*`. Prefer a small bespoke `lib/` module over any external dependency.
5. **Run via Windows LÖVE.** LÖVE 11.5 lives on Windows at `/mnt/c/Program Files/LOVE/love.exe` and is launched from WSL through interop (see [How to run](#how-to-run)). There is no LÖVE installed inside WSL.

## The core loop

`main.lua` is the entry point. Define these callbacks; LÖVE invokes them each frame. `dt` is seconds since the last frame — the only reliable clock.

```lua
function love.load() end        -- once, at start; create assets, load state, window
function love.update(dt) end    -- every frame: move state forward by dt
function love.draw() end        -- every frame, after update: all rendering
```

Other callbacks you will reach for, named exactly:

`love.keypressed(key, scancode, isrepeat)`, `love.keyreleased`, `love.textinput(t)`, `love.mousepressed(x, y, button, istouch, presses)`, `love.mousemoved(x, y, dx, dy)`, `love.wheelmoved(dx, dy)`, `love.focus(f)`, `love.resize(w, h)`, `love.joystickpressed(joystick, button)`, `love.gamepadpressed(joystick, button)`, `love.touchpressed(id, x, y, dx, dy, pressure)`, and `love.quit()` (return `false` from it to cancel a quit). Input arriving mid-frame is queued and delivered before the next `update`, so state changes inside input callbacks apply that same frame.

Every interactive game needs a **state variable** (`x = x + vx*dt` in `update`) and draws it from that state in `draw`. Never mutate position directly inside a draw call.

## How to run

From WSL, point Windows LÖVE at the project as a **Windows path**:

```bash
"/mnt/c/Program Files/LOVE/love.exe" "$(wslpath -w "$PWD")"
```

This opens the game window on Windows. The conventional wrapper is a `run-game.sh` in the repo root that runs exactly that command; if the user has one, use it.

## Creating an asset — the decision in one line

Before writing any visual/audio code, decide what artifact you need, then reach for the matching procedural pattern. Every branch is in the reference:

- **Shape on screen** → draw a primitive (`love.graphics.rectangle`/`circle`/`polygon`/`line`) — no asset.
- **Texture / sprite** → build an `ImageData` with `love.image.newImageData` + `:setPixel`, then `love.graphics.newImage(imageData)`.
- **Repeated / many-of-one** → one `Image`, drawn many times, or a `Mesh`/`SpriteBatch`/`ParticleSystem`.
- **Text / UI** → `love.graphics.newFont(size)` (embedded font) + `print`/`printf`; a generated bitmap font via `love.graphics.newImageFont` for stylised glyphs.
- **Sound / music** → synthesize samples into a `SoundData` with `love.sound.newSoundData` + `:setSample`, then `love.audio.newSource(soundData, "static")`.
- **Randomness / noise / geometry math** → `love.math.*`.
- **Off-screen composition** → render into a `Canvas`, then draw the canvas.

Full signatures, gotchas, and per-module detail: **[`REFERENCE.md`](REFERENCE.md)** — reach it when you need an exact signature, a coordinate/color convention, or a procedural pattern. The reference is the single source of truth for API specifics; keep it here, not duplicated in your session notes.

## Roadmap for a whole feature

1. **Read the getting-started context** below if you are new to this repo, then open `REFERENCE.md` and find the branch for the artifact you need.
2. **Create the asset procedurally in `love.load`** (or lazily on first use), store the object on a local/`love`-level variable, reuse it.
3. **Drive it from state** in `love.update(dt)`; **render it** in `love.draw()`.
4. **Verify by running** (`run-game.sh`) and by reading the code back: state-driven, procedural, native-only.
