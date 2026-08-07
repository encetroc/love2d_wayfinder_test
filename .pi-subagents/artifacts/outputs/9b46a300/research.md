# Procedural sprite & tile asset pipeline

> Repo note for GitHub issue #7 — design decision. Native-only LÖVE 11.5, no external asset files. GBC-Zelda-style top-down tile grid, flat-geometric + neon visual style. **Pattern per artifact: build `ImageData` pixel-by-pixel in code → `love.graphics.newImage(imageData)`; render many tiles with a `SpriteBatch`; compose off-screen with a `Canvas`; add neon glow with `love.graphics.setBlendMode("add")`.** All generation logic lives in `lib/assets.lua`, called once from `love.load`.

---

## Primary decision lines (from this repo's authoritative reference)

The repo's own LÖVE 11.5 reference (`.agents/skills/love2d/REFERENCE.md`) fixes the pattern and is the **single source of truth**. Its explicit decision lines:

- **Colors are 0..1 floats** everywhere (`r,g,b,a`). `ImageData:setPixel` and `love.graphics.setColor` take floats; passing 0..255 "silently burns out." This is called out as **the single most common 11.x bug** in the Gotchas. [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
- **Procedural images pattern:** *"build `ImageData` pixel-by-pixel in code → `love.graphics.newImage(imageData)`. No `.png` ever committed."* [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
- **Rendering many tiles:** `SpriteBatch = love.graphics.newSpriteBatch(image, capacity)` → `batch:add(x, y, ...)` then one `love.graphics.draw(batch)`. *"Ideal for many instances of one texture."* [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
- **Off-screen composition:** `Canvas` via `love.graphics.newCanvas(w, h)` + `love.graphics.setCanvas(canvas)` → draw into it → `setCanvas()` → draw the canvas whole. Use for bloom/caches of expensive procedural art. [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
- **Neon glow:** `love.graphics.setBlendMode("add")` — *"`add` for glow/explosions."* [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
- **Create assets once**, in `love.load` or lazily, and reuse — building `ImageData`/fonts/Sources every frame floods the GC. [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
- **Hard rule:** *"No asset files exist in this repo by design. If you're tempted to load a `.png`/`.wav`/`.ttf`, generate the equivalent in code instead (see the procedural sections). This is a hard rule."* [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)

The central sample the reference gives is a soft radial gradient circle written floor-over-pixel into an `ImageData`. Everything below extends exactly that loop.

---

## 1. LÖVE 11.5 API specifics (primary source — official wiki)

### `love.image.newImageData`

`imageData = love.image.newImageData(width, height, format, rawdata)` — `format` defaults to `"rgba8"` (`PixelFormat`). Pure-code creation, no filepath. [love.image.newImageData](https://love2d.org/wiki/love.image.newImageData) · [PixelFormat](https://love2d.org/wiki/PixelFormat)

### `ImageData:setPixel`

`ImageData:setPixel(x, y, r, g, b, a)`. **Valid x/y start at 0**, up to width−1 / height−1. Color components are **0..1 floats since 11.0** (0..255 in older versions). *"This function locks the ImageData until it is done, making it safe to use from multiple Threads."* [ImageData:setPixel](https://love2d.org/wiki/ImageData:setPixel)

### Other `ImageData` API (all confirmed by official docs)

- `:getPixel(x, y)` → `r, g, b, a` (0..1 floats)
- `:getWidth()/getHeight()/getDimensions()`
- `:mapPixel(fn)` — higher-order, calls `fn(x, y, r, g, b, a)` once per pixel; perfect for atomic palette/glow remaps after the base loop. [ImageData:mapPixel](https://love2d.org/wiki/ImageData:mapPixel)
- `:paste(src, dx, dy)` — blit one ImageData into another (splice sprites into an atlas).
- `:getString()` → full raw byte string; `:encode("png"|"tga", filename)` — write-to-disk only if ever needed for debugging (optional, not required for native-only). [ImageData](https://love2d.org/wiki/ImageData) · [ImageData:encode](https://love2d.org/wiki/ImageData:encode)

### `love.graphics.newImage`

`image = love.graphics.newImage(imageData)` — accepts an `ImageData` directly; the Image "will use this ImageData to reload itself when love.window.setMode is called." This is the bridge from CPU `ImageData` to GPU texture. [love.graphics.newImage](https://love2d.org/wiki/love.graphics.newImage)

### `love.graphics.newSpriteBatch` / `SpriteBatch:add`

`spriteBatch = love.graphics.newSpriteBatch(image, maxsprites)` — since 11.0, sprites past capacity are handled automatically. `SpriteBatch:add(x, y, r, sx, sy, ox, oy, kx, ky)` returns an id; `SpriteBatch:set(id, x, y, ...)` updates one sprite in place (ideal for moving the player/enemies without rebuilding the batch). Draw the whole batch with one `love.graphics.draw(batch)`. [love.graphics.newSpriteBatch](https://love2d.org/wiki/love.graphics.newSpriteBatch) · [SpriteBatch:add](https://love2d.org/wiki/SpriteBatch:add) · [SpriteBatch:set](https://love2d.org/wiki/SpriteBatch:set). For a top-down static tile grid this is the canonical many-instances-of-one-texture path — the wiki's [Efficient Tile-based Scrolling](https://love2d.org/wiki/Tutorial:Efficient_Tile-based_Scrolling) tutorial pairs Quads + SpriteBatch exactly for this.

### `love.graphics.newCanvas` / `setCanvas`

`canvas = love.graphics.newCanvas(width, height)`; `love.graphics.setCanvas(canvas)` redirects all draws off-screen until the next `setCanvas()` (or `setCanvas()` with no arg back to screen); then `love.graphics.draw(canvas, 0, 0)`. Default canvas dims = window pixels. Recreate/resize in `love.resize`. [love.graphics.newCanvas](https://love2d.org/wiki/love.graphics.newCanvas) · [Canvas](https://love2d.org/wiki/Canvas)

### `love.graphics.setBlendMode`

`love.graphics.setBlendMode(mode, alphamode)`; `"add"` = "pixel colors of what's drawn are **added** to the pixel colors already on the screen" — this is the neon glow pass. Must push/pop back to `"alpha"` (default `"alphamultiply"`) after the glow pass. [love.graphics.setBlendMode](https://love2d.org/wiki/love.graphics.setBlendMode) · [BlendMode](https://love2d.org/wiki/BlendMode)

### `love.graphics.newMesh`

`mesh = love.graphics.newMesh(vertices, mode, usage)`; vertex = `{x, y, u, v, r, g, b, a}`; `mesh:setTexture(image)`. Per-vertex colors enable per-corner tints (e.g. a single white procedural triangle tinted per-side), and `"fan"`/`"strip"`/`"triangles"` give cheap flat-geometric shapes. [love.graphics.newMesh](https://love2d.org/wiki/love.graphics.newMesh)

---

## 2. Reading flat-geometric + neon at small tile sizes

Key design constraint: **how flat shapes + neon glow read at small tile sizes.** Tile pixels are raw (no smoothing), and a neon glow is just a soft falloff of low alpha that accumulates under additive blending.

- **2–3 px hard silhouette + 2–3 px glow falloff.** With `setPixel`, you control the alpha ramp directly: the solid core is `a = 1` inside the flat shape; the glow ring is `a` falling to 0 over the next few pixels. `math.max(0, 1 - d)`-style falloff (see REFERENCE radial sample) gives a readable halo even on an 8×8–16×16 tile.
- **The additive glow pass is what makes "flat + neon" read.** A flat filled shape alone looks flat and dull; the same shape drawn second (or written into an `ImageData` as a halo) with `setBlendMode("add")` produces the bright edge that reads as "neon" without any shader. This is the documented use of `"add"` for glow in the reference, and the wiki confirms `add` sums colors on screen. The community does the same multi-pass trick (draw the shape several times at increasing line width / decreasing alpha) for lined glow. [ebens.me glow technique](https://ebens.me/posts/glow-effect-for-lined-shapes-in-love2d/)
- **Two valid ways to hit neon:** (a) embed the halo in the ImageData itself (flat core + fading alpha ring baked in — one draw call, snapshot); or (b) keep the flat core opaque and overlay a soft radial glow image with `setBlendMode("add")` (two draw calls, but the glow is reusable/tintable). **Recommendation: bake the halo into the ImageData** for tiles (static, cheapest), and use the additive pass only for the player/enemies/projectiles (which need to read as "emissive") and for hit FX.
- **Whites/high-sat cores over dark background.** Neon pops on the dark floor/wall palette. Keep walls dark-navy/graphite, floor near-black, and reserve saturated magenta/cyan/lime for entities + glow.

---

## 3. Proposed primitive set + owning module

**Owning module: `lib/assets.lua`** (mirrors the reference's naming and single-context repo layout). It exports a table of generated primitives, built once in `love.load` via `assets.init()`, then reused every frame. No `require` of any image file.

Resolution decision: **tile grid = GBC-Zelda top-down → 16×16 tiles**, sprites also 16×16 (GBC Zelda was 16×16 tiles with 8×8 sub-tiles; 16 is a clean, small, fast `setPixel` target and keeps procedural generation trivial). Player/enemies project over 1 tile (16×16) with a few glow pixels bleeding out.

| Primitive | Type | ImageData size | Owner gen fn | Notes |
| --- | --- | --- | --- | --- |
| `floor` tile | ImageData 16×16 | static | `genFloor()` | near-black base + faint 1px grid line / subtle noise via `love.math.noise` for texture |
| `wall` tile | ImageData 16×16 | static | `genWall()` | dark graphite fill + bright 1px top/left edge highlight = reads as a solid block from top-down |
| `player` sprite | ImageData 16×16 | static | `genPlayer()` | flat diamond/cross core (cyan/white) + baked halo + additive pass at draw |
| `enemy_chaser` | ImageData 16×16 | static | `genEnemyChaser()` | magenta triangle core + halo |
| `enemy_shooter` | ImageData 16×16 | static | `genEnemyShooter()` | orange square core + halo |
| `enemy_tank` | ImageData 16×16 | static | `genEnemyTank()` | large red hexagon / 2-tile-ish block silhouette + thick halo (slow, tough) |
| `projectile` | ImageData 8×8 | static | `genProjectile()` | tiny bright circle + short glow tail; tinted per-faction at draw (`setColor`) |
| `glow` sprite | ImageData 16×16 | static | `genGlow()` | pure soft radial gradient, alpha-only — tintable, added additively for FX |
| `particle1` | ImageData 4×4 | static | `genParticle()` | 1-px-ish soft dot, feeds `ParticleSystem` |

Each of the entity sprites belongs to one of the two categories:

- **Core + baked halo** (tiles, entities): one `ImageData` carrying both the flat geometric core and its alpha-fading glow ring (option 2a above) → one draw call each.
- **Core + additive overlay glow** (player, enemies, projectiles, hit FX): draw the core, then draw `glow` (or the entity glow image) with `setBlendMode("add")` → bright "emissive" edge.

---

## 4. Concrete code pattern per artifact

### 4.1 Core `ImageData` builder (one shared shape helper)

The single pattern that all artifacts share. From REFERENCE's canonical loop, generalized so a per-pixel closure returns `(r,g,b,a)`:

```lua
-- lib/assets.lua
local function buildImage(w, h, pixelFn)      -- pixelFn(x,y) -> r,g,b,a  (all 0..1 floats)
  local id = love.image.newImageData(w, h)     -- default "rgba8"
  for y = 0, h-1 do
    for x = 0, w-1 do
      local r, g, b, a = pixelFn(x, y)
      id:setPixel(x, y, r, g, b, a)            -- NOTE: x,y and colors are 0-indexed / 0..1
    end
  end
  return love.graphics.newImage(id)            -- ImageData -> GPU Image
end
```

### 4.2 Floor tile — flat base + faint texture (via `love.math.noise`)

```lua
local FLOOR = {0.06, 0.05, 0.10}               -- near-black base
local function genFloor()
  return buildImage(16, 16, function(x, y)
    local n = love.math.noise(x * 0.4, y * 0.4)         -- 0..1-ish ambient dither
    local v = 0.06 + n * 0.012                          -- subtle luminance variation
    return FLOOR[1]+v, FLOOR[2]+v, FLOOR[3]+v, 1
  end)
end
```

`love.math.noise` is deliberately not used for *layout* (per sibling note on reproducible map layout); here it is only ambient tile texture, which is its correct use. Build once, reuse.

### 4.3 Wall tile — flat block + neon edge highlight

```lua
local function genWall()
  return buildImage(16, 16, function(x, y)
    if x == 0 or y == 0 then return 0.35, 0.9, 1.0, 1 end    -- bright cyan top/left edge = solid block read
    if x == 15 or y == 15 then return 0.05, 0.05, 0.08, 1 end -- recessed far edge
    return 0.12, 0.11, 0.16, 1                                -- dark graphite body
  end)
end
```

### 4.4 Baked-halo primitive (entities) — flat core + alpha-fading glow ring

This is the **neon recipe** inside one ImageData. Flat core pixels are `a=1` in a saturated bright color; the ring falls off to 0 so it reads as glow at small size. This is exactly REFERENCE's radial falloff `math.max(0, 1 - d)` applied as an alpha ramp.

```lua
local CYAN = {0.2, 1.0, 1.0}                     -- neon cyan player core
local function genPlayer()
  local cx, cy = 8, 8; local coreR = 4.5
  return buildImage(16, 16, function(x, y)
    local d = math.sqrt((x - cx)^2 + (y - cy)^2)
    if d <= coreR then
      return CYAN[1], CYAN[2], CYAN[3], 1        -- flat core, fully opaque
    end
    local a = math.max(0, 1 - (d - coreR) / 3)   -- 3px glow falloff (baked halo)
    return CYAN[1], CYAN[2], CYAN[3], a * 0.5
  end)
end
```

Cross/arrow shapes: constrain the core by testing `math.abs(x-cx) < 2 or math.abs(y-cy) < 2` inside `d <= coreR`.

### 4.5 Rendering many tiles — `SpriteBatch` (one batch per tile type)

Static top-down grid = build one `SpriteBatch` per tile type in `love.load` and rebuild only when the map/room changes.

```lua
local batch = love.graphics.newSpriteBatch(assets.floor, mapW * mapH)
for ty = 0, mapH-1 do
  for tx = 0, mapW-1 do
    batch:add(tx * TILE, ty * TILE, 0, 1, 1, 0, 0)
  end
end
-- one draw per tile layer:
love.graphics.draw(batch)
```

Move per-tile updates with `SpriteBatch:set(id, ...)` using the id returned by `:add` (e.g. door opening, tiles that break). Wiki tutorial: Quad + SpriteBatch for efficient tile scrolling. [love.graphics.newSpriteBatch](https://love2d.org/wiki/love.graphics.newSpriteBatch) · [SpriteBatch:set](https://love2d.org/wiki/SpriteBatch:set)

### 4.6 Additive neon pass for entities + FX

Player/enemies/projectiles drawn with an extra additive glow overlay so they read as emissive:

```lua
function assets.drawGlow(image, x, y)
  love.graphics.setBlendMode("add")             -- add = pixel colors summed on screen (neon)
  love.graphics.setColor(1, 1, 1, 0.8)
  love.graphics.draw(image, x, y)
  love.graphics.setBlendMode("alpha")           -- back to default "alphamultiply"
end
```

Use the shared `assets.glow` (alpha-only radial gradient) tinted per-faction with `setColor` for hit flashes. [BlendMode - add](https://love2d.org/wiki/BlendMode)

### 4.7 Off-screen composition — Canvas (camera-relative / cached art)

For expensive procedural art or camera-at-rest UI, bake to a Canvas once and draw the single drawable per frame. Recreate in `love.resize` (canvas default = window pixels).

```lua
local cam = love.graphics.newCanvas(W, H)
love.graphics.setCanvas(cam)
love.graphics.clear(0, 0, 0, 0)
-- ... draw world + glow passes here ...
love.graphics.setCanvas()
-- per frame:
love.graphics.setColor(1, 1, 1, 1)
love.graphics.draw(cam, 0, 0)
```

[love.graphics.newCanvas](https://love2d.org/wiki/love.graphics.newCanvas)

### 4.8 Mesh alternative for pure flat geometry

For strictly flat shapes with an even cheaper path than an ImageData, `love.graphics.newMesh({ {x,y,u,v,r,g,b,a}, ... }, "fan")` + `mesh:setTexture(authoringImage)` gives per-vertex color. Prefer for triangle/hexagon silhouettes where you want per-corner tints (e.g. tank hexagon edge brighter than center). [love.graphics.newMesh](https://love2d.org/wiki/love.graphics.newMesh)

---

## 5. Concrete generation recipe (order inside `lib/assets.lua:init()`)

1. Define palette constants (all 0..1 floats): e.g. `FLOOR={0.06,0.05,0.10}`, `WALL_EDGE={0.35,0.90,1.0}`, `NEON_CYAN={0.2,1,1}`, `NEON_MAGENTA`, `NEON_ORANGE`, `NEON_LIME`, `RED_TANK`.
2. Build shared helpers: `buildImage(w,h,pixelFn)` (4.1) and the atomic `glow` / `particle1` sprites.
3. Generate static tile primitives: `floor`, `wall` (4.2–4.3).
4. Generate entity sprites: `player`, `enemy_chaser`, `enemy_shooter`, `enemy_tank`, `projectile` via the baked-halo recipe (4.4), differentiated by shape + palette.
5. Build tile `SpriteBatch`es (4.5) from the current map/room.
6. Only open canvases that are truly reused (camera/fill-light) (4.7).
7. Everything is built once; `love.load` calls `assets.init()` before the game state. Never rebuild per frame (GC).

---

## 6. Gotchas to respect (from REFERENCE, primary)

- **Colors are 0..1 floats** — do not pass 255 anywhere; it silently clamps/burns. Apply to `setPixel`, `setColor`, mesh vertex colors. [REFERENCE.md Gotchas](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
- **`ImageData:setPixel` x/y are 0-indexed** (0..w−1) — the reference loop uses `for y = 0, h-1`. [ImageData:setPixel](https://love2d.org/wiki/ImageData:setPixel)
- **Build assets once** in `love.load`/`init`; never in `draw`. [REFERENCE.md Gotchas](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
- **No asset files, period** — generate equivalents in code. Hard rule. [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
- **11.5 vs 12.x**: stay on 11.5 names (`love.image`, `ImageData`, `love.graphics.newImage/newSpriteBatch/newCanvas/newMesh`); don't reach for 12.x renames (`love.data.lz4`, `phoenix`, Noto default font). [REFERENCE.md Gotchas](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)

---

## Findings summary (numbering)

1. **The pipeline is `ImageData:setPixel` → `love.graphics.newImage`.** Every artifact starts as a 0..1-float pixel buffer written in code; `newImage(imageData)` bridges it to the GPU and auto-reloads on `setMode`. [love.image.newImageData](https://love2d.org/wiki/love.image.newImageData) · [ImageData:setPixel](https://love2d.org/wiki/ImageData:setPixel) · [love.graphics.newImage](https://love2d.org/wiki/love.graphics.newImage)
2. **`SpriteBatch` is the many-tiles renderer** (one batch per tile type, drawn with a single `graphics.draw`); `SpriteBatch:set(id, ...)` for per-tile updates. [love.graphics.newSpriteBatch](https://love2d.org/wiki/love.graphics.newSpriteBatch) · [Efficient Tile-based Scrolling](https://love2d.org/wiki/Tutorial:Efficient_Tile-based_Scrolling)
3. **`Canvas` handles off-screen composition/bloom**; default = window pixels, recreate in `love.resize`. [love.graphics.newCanvas](https://love2d.org/wiki/love.graphics.newCanvas)
4. **Neon glow = `setBlendMode("add")`** for an emissive additive pass plus an alpha-falloff halo baked into the ImageData; this is both the reference's documented `add`-for-glow and the community multi-pass glow idiom. [BlendMode](https://love2d.org/wiki/BlendMode) · [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)
5. **Flat geometry at small size** reads via a 2–3 px opaque core + 2–3 px glow falloff on a dark floor/wall base; `love.math.noise` is fine for ambient floor texture (not map layout). [REFERENCE.md](file:///home/encetroc/love2d_wayfinder_test/.agents/skills/love2d/REFERENCE.md)

---

## Sources

- Kept:
  - `.agents/skills/love2d/REFERENCE.md` — the repo's pinned 11.5 single-source-of-truth for APIs, procedural patterns, and gotchas. *(local primary)*
  - love2d.org wiki `ImageData`, `ImageData:setPixel`, `love.image.newImageData` — official signatures, 0-indexing, 0..1 color range. (<https://love2d.org/wiki/ImageData> · <https://love2d.org/wiki/ImageData:setPixel> · <https://love2d.org/wiki/love.image.newImageData>)
  - love2d.org wiki `love.graphics.newImage`, `newSpriteBatch`, `SpriteBatch:add/set`, `newCanvas`, `setBlendMode`, `BlendMode`, `PixelFormat`, `newMesh` — official rendering API. (<https://love2d.org/wiki/love.graphics.newImage>) etc.
  - love2d.org wiki tutorial "Efficient Tile-based Scrolling" — canonical Quad+SpriteBatch tile rendering. (<https://love2d.org/wiki/Tutorial:Efficient_Tile-based_Scrolling>)
- Dropped:
  - prust/sti-pg-example, HamdyElzanqali/ldtk-love, aloisdeniel/love-pixelmap, tesselode/cartographer — external Tiled/LDtk loader libs; irrelevant (repo is native-only, no asset files, no third-party map lib).
  - kikito/love-tile-tutorial — general tile tutorial, superseded by the more specific wiki "Efficient Tile-based Scrolling" and the local reference.
  - leafo.net / typeerror.org / W3cubDocs mirrors — wiki mirrors, superseded by primary love2d.org pages.

## Gaps

- Exact GBC-Zelda tile pixel dimensions are inferred (16×16) from the classic GBC Zelda convention, not from an issue spec; the map/room tile size should be confirmed against the map layout decision (sibling issue #12 uses ~40×30 tiles). Suggested next step: confirm `TILE` constant (16 vs 8) once the map spec is settled, then lock `lib/assets.lua` chunk sizes to it.
- Whether the drawer should separate tile "base pass" (opaque) from "glow pass" (additive) with a shared tintable `glow` sprite is a stylistic choice; the two options (baked halo vs additive overlay) are both valid and both offered above.
- No `lib/assets.lua` exists yet in the repo to diff against; the module name matches the reference/repo naming convention but should be confirmed when implemented.

---

## Acceptance report

The findings above are concrete and cited to primary sources (the repo's pinned `REFERENCE.md` + love2d.org official wiki), with exact LÖVE 11.5 API signatures, a per-artifact `setPixel` pattern, a proposed primitive set (7 ImageData sprites + particle + glow), the owning module (`lib/assets.lua`), and a concrete generation recipe.

```acceptance-report
{
  "criteriaSatisfied": [
    {
      "id": "criterion-1",
      "status": "satisfied",
      "evidence": "Returned concrete, decisive findings with exact LÖVE 11.5 API signatures (ImageData:setPixel 0-indexed 0..1 floats, love.graphics.newImage/newSpriteBatch/newCanvas/newMesh, SpriteBatch:set, setBlendMode('add')) cited to love2d.org wiki and the repo's pinned REFERENCE.md. Findings include file paths: the owning module lib/assets.lua (proposed) and the local primary .agents/skills/love2d/REFERENCE.md. Per-artifact patterns for floor/wall/player/enemy_chaser/enemy_shooter/enemy_tank/projectile with concrete setPixel loop shapes, neon palette approach, and SpriteBatch usage are provided in the saved research note."
    }
  ],
  "changedFiles": [
    ".pi-subagents/artifacts/outputs/9b46a300/research.md"
  ],
  "testsAddedOrUpdated": [],
  "commandsRun": [
    {
      "command": "read REFERENCE.md + love2d.org wiki via web_search (love.image.newImageData, ImageData:setPixel, newSpriteBatch, newCanvas, setBlendMode, newMesh + tutorial)",
      "result": "passed",
      "summary": "Read the repo's local LÖVE 11.5 reference first, then confirmed all API signatures against the official love2d.org wiki (multiple parallel queries)."
    },
    {
      "command": "write .pi-subagents/artifacts/outputs/9b46a300/research.md",
      "result": "passed",
      "summary": "Wrote the full research brief (procedural sprite & tile asset pipeline) to the authoritative output path; succeeded (22092 bytes), auto-lint fixed markdown."
    }
  ],
  "validationOutput": [
    "Research brief written to authoritative path /home/encetroc/love2d_wayfinder_test/.pi-subagents/artifacts/outputs/9b46a300/research.md and re-read to confirm content. All LÖVE 11.5 API claims cross-checked against primary love2d.org wiki pages."
  ],
  "residualRisks": [
    "Tile size (16x16) inferred from GBC-Zelda convention, not confirmed against issue #7 spec; confirm the TILE constant once the map layout (issue #12) is settled.",
    "lib/assets.lua does not yet exist in repo; module name is proposed following repo naming convention and should be confirmed at implementation.",
    "baked-halo vs additive-overlay glow is a stylistic choice; both are offered and either is valid."
  ],
  "noStagedFiles": true,
  "diffSummary": "Created new research note at .pi-subagents/artifacts/outputs/9b46a300/research.md documenting the procedural sprite & tile asset pipeline for issue #7: per-artifact ImageData:setPixel patterns, proposed primitive set, owning module lib/assets.lua, and LÖVE 11.5 API specifics.",
  "reviewFindings": [
    "no blockers - findings fully grounded in the repo's pinned REFERENCE.md and the official love2d.org wiki (primary sources); no contradictions found between local reference and wiki signatures."
  ],
  "manualNotes": "Client has no file-name auto-fix conflict; the auto-lint only adjusted markdown whitespace. Tile-size and module-name are the only open items, flagged in residualRisks for the parent to resolve against issue #7/#12 specs before implementation."
}
```
