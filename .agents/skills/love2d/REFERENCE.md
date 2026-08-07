# LÖVE 11.5 API reference

Reached from `SKILL.md` when you need an exact signature, a coordinate/color convention, or a procedural asset pattern. This is the **single source of truth** for API specifics. Version pinned: **11.5** (Lua 5.1, `love.*` modules). Native-only, procedural assets, no external libs.

- [Global conventions](#global-conventions)
- [Modules cheat sheet](#modules-cheat-sheet)
- [Core loop & callbacks](#core-loop--callbacks)
- [Rendering: graphics](#rendering-graphics)
- [Procedural images (no asset files)](#procedural-images-no-asset-files)
- [Procedural text & fonts](#procedural-text--fonts)
- [Procedural audio (no asset files)](#procedural-audio-no-asset-files)
- [Input: keyboard / mouse / gamepad / touch](#input)
- [Math: random, noise, geometry](#math-random-noise-geometry)
- [Data & filesystem](#data--filesystem)
- [Window, system, timer, misc](#window-system-timer-misc)
- [Physics (optional)](#physics-optional)
- [Gotchas](#gotchas)

## Global conventions

- **Colors** are **0..1 floats** (`r,g,b,a`), everywhere — `love.graphics.setColor`, `ImageData:setPixel`, mesh vertex colors. Passing 0..255 breaks rendering (values clamp).
- **Angles** are **radians**. **0 = +x axis (right)**, increasing **counter-clockwise** on screen (y-down makes it read as clockwise in world terms).
- **Origin** is the **top-left**; **x grows right, y grows down**. "Move up" = subtract from `y`.
- **Time** comes from `dt` (seconds since last frame) passed to `love.update`. Scale all movement by `dt`. `love.timer.getTime()` is absolute-ish seconds (differences only).
- **Coordinate space** in `draw` is the window in pixels (see `love.graphics.getWidth/Height`); with `highdpi` this can differ from `love.window.getWidth`.

## Modules cheat sheet

| Need | Module |
| --- | --- |
| Draw shapes/images/text | `love.graphics` |
| The screen/window | `love.window`, `love.graphics` |
| Make images in code | `love.image` |
| Audio playback + volume | `love.audio` |
| Make/load sound samples | `love.sound` |
| Keys | `love.keyboard` |
| Mouse/cursor | `love.mouse` |
| Controller/gamepad | `love.joystick` |
| Touch | `love.touch` |
| Random/noise/geometry | `love.math` |
| Compression/encode/hash | `love.data` |
| Files (save/read) | `love.filesystem` |
| Clock | `love.timer`, `love.event` |
| Sub-processes | `love.thread` |
| Optional 2D physics | `love.physics` |
| Video | `love.video` |
| OS info/URL/clipboard | `love.system` |

## Core loop & callbacks

Callbacks live in `main.lua`; LÖVE calls them. `love.load` once, then `update`/`draw` every frame.

```lua
function love.load()                -- create procedural assets, init state, set window
  love.window.setTitle("My Game")
  love.graphics.setBackgroundColor(0.1, 0.1, 0.13)
end
function love.update(dt)            -- advance state by dt; all logic here
  player.x = player.x + player.vx * dt
end
function love.draw()                -- render ONLY from state
  love.graphics.circle("fill", player.x, player.y, 20)
end
```

Input callbacks (edge-triggered, run before the next `update`): `love.keypressed(key, scancode, isrepeat)`, `love.keyreleased(key, scancode)`, `love.textinput(text)`, `love.mousepressed(x, y, button, istouch, presses)`, `love.mousereleased`, `love.mousemoved(x, y, dx, dy)`, `love.wheelmoved(dx, dy)`, `love.focus(f)`, `love.resize(w, h)`, `love.joystickpressed(js, b)`, `love.joystickreleased`, `love.gamepadpressed(js, b)`, `love.gamepadaxis(js, axis, value)`, `love.touchpressed(id, x, y, dx, dy, pressure)`, `love.touchmoved`, `love.touchreleased`, and `love.quit()`. Held keys → poll `love.keyboard.isDown` in `update`.

## Rendering: graphics

### Primitives (no asset needed — the default answer for "a shape")

All take a `mode` = `"fill"` or `"line"`.

```lua
love.graphics.rectangle("fill", x, y, w, h)                       -- w,h optional rounded: , rx, ry, segments
love.graphics.circle("fill", x, y, radius, segments)              -- default segments ~ smooth
love.graphics.ellipse("fill", x, y, radiusX, radiusY, segments)
love.graphics.arc("fill", x, y, radius, angle1, angle2, segments)
love.graphics.sector("fill", x, y, radius, angle1, angle2, segments)  -- pie slice, for gauges/fan visuals
love.graphics.polygon("fill", x1,y1, x2,y2, x3,y3, ...)           -- concave ok when filled
love.graphics.line(x1,y1, x2,y2, ...)                              -- optional leading width arg
love.graphics.points(x1,y1, x2,y2, ...)                            -- squares; see setPointSize
love.graphics.quad("fill", x1,y1, x2,y2, x3,y3, x4,y4)             -- 4 arbitrary corners
```

Style before drawing: `love.graphics.setColor(r,g,b,a)` (tints **and** fills; default white `1,1,1,1`), `love.graphics.setLineWidth(w)`, `love.graphics.setLineStyle("smooth"|"rough")`, `love.graphics.setPointSize(n)`, `love.graphics.setBackgroundColor(...)`, `love.graphics.setBlendMode("alpha"|"add"|"subtract"|"multiply"|"replace"|"screen")` — `"add"` for glow/explosions.

### Transforms (isolate with push/pop)

```lua
love.graphics.push()   -- save transform
love.graphics.translate(tx, ty)
love.graphics.rotate(r)          -- radians
love.graphics.scale(sx, sy)
love.graphics.shear(kx, ky)
love.graphics.pop()    -- restore
love.graphics.origin() -- reset to identity
```

### Draw an object

```lua
love.graphics.draw(drawable, x, y)                                  -- image/mesh/canvas/spritebatch/quad/text/video
love.graphics.draw(drawable, x, y, r, sx, sy, ox, oy, kx, ky)      -- rotate r, scale, pivot at ox,oy
love.graphics.draw(drawable, transform)                             -- or a love.math.newTransform
```

### Off-screen composition: Canvas

```lua
local canvas = love.graphics.newCanvas(w, h)   -- default = window pixel size
love.graphics.setCanvas(canvas)                -- draw INTO it from here
-- ... draw things ...
love.graphics.setCanvas()                      -- back to screen
love.graphics.setColor(1,1,1,1)
love.graphics.draw(canvas, 0, 0)               -- then draw the whole thing
```

Resize it in `love.resize` if the window changes. Use for bloom, world-camera-at-rest UI, or caches of expensive procedural art.

### Shaders (native GLSL)

`love.graphics.newShader(vertexCode, fragmentCode)`; `love.graphics.setShader(shader)` / `setShader()` to clear. Fragment uses GLSL `vec4 effect(vec4 color, Image texture, vec2 texcoord, vec2 pixcoord)`. `shader:send("name", value)` for uniforms. For pixel/grid effects (CRT, wave, palette), this is native and allowed — but prefer primitives when a shader isn't paying for itself.

## Procedural images (no asset files)

**The pattern:** build `ImageData` pixel-by-pixel in code → `love.graphics.newImage(imageData)`. No `.png` ever committed.

```lua
local w, h = 64, 64
local id = love.image.newImageData(w, h)
for y = 0, h-1 do
  for x = 0, w-1 do
    -- r,g,b,a are 0..1 floats
    local d = math.sqrt((x-32)^2 + (y-32)^2) / 32
    local a = math.max(0, 1 - d)          -- fade out with distance
    id:setPixel(x, y, 1.0, 0.4, 0.2, a)   -- soft orange circle texture
  end
end
local img = love.graphics.newImage(id)
-- reuse `img` in draw: love.graphics.draw(img, x, y)
```

`ImageData` API: `:setPixel(x, y, r, g, b, a)` (also accepts a 4-table), `:getPixel(x, y)` → `r,g,b,a`, `:getWidth()/getHeight()/getDimensions()`, `:mapPixel(fn)` remaps all, `:paste(src, dx, dy)`, `:encode("png"|"tga", filename)` (write to filesystem if you ever need to), `:getString()`. Construct with `love.image.newImageData(w, h)` or `love.image.newImageData(w, h, format)` (`format` e.g. `"rgba8"` default, `"rgb8"`, `"r8"`).

**Texture helpers** that multiply one procedural texture:

- `quad = love.graphics.newQuad(left, top, w, h, imageW, imageH)` → use `love.graphics.draw(image, quad, x, y)` and `SpriteBatch:add(quad, x, y, ...)`.
- `batch = love.graphics.newSpriteBatch(image, capacity)` → `batch:add(x, y, r, sx, sy, ox, oy)` (or `batch:add(quad, ...)`), then `love.graphics.draw(batch)`. Ideal for many instances of one texture.
- `mesh = love.graphics.newMesh(vertices)` where each vertex is `{x, y, u, v, r, g, b, a}`; `mesh:setTexture(image)`; distort/spin. `love.graphics.newMesh(vertices, "fan"|"strip"|"triangles", "static"|"dynamic"|"stream")`.

### Particle systems (procedural FX)

```lua
local ps = love.graphics.newParticleSystem(starImage, 1000)  -- any Image; or a 1px image tinted
ps:setParticleLifetime(0.5, 1.5)
ps:setEmissionRate(100)
ps:setSpeed(60, 120)
ps:setSpread(math.pi)              -- full circle
ps:setGravity(200)
ps:setSizeVariation(0.5)
ps:setColors(1,1,1,1, 1,0.5,0,0)   -- start→end color ramps (floats)
ps:setDirection(0)
ps:start()
-- in update: ps:update(dt); in draw: love.graphics.draw(ps, x, y)
-- one-off burst instead of continuous: stop emission, ps:emit(n)
```

## Procedural text & fonts

```lua
local font = love.graphics.newFont(24)      -- embedded font at 24px (no file)
love.graphics.setFont(font)
love.graphics.setNewFont(28)                -- create+set in one call
love.graphics.print("Hello", x, y)
love.graphics.printf("Wrapped text", x, y, limitWidth, "left"|"center"|"right")
love.graphics.print("Hi", x, y, r, sx, sy, ox, oy)   -- tinted/rotated like draw
```

Measuring: `font:getWidth("text")`, `font:getHeight("text")` (height = line height), `font:getWrap(text, limit)` → lines + height. The default font when none is set is the embedded TrueType (~12–13px). For pixel/stylised glyphs without an asset, build glyphs in `ImageData` and use `love.graphics.newImageFont(imageData, "glyphs string")` where the glyph string maps rows/columns to characters.

## Procedural audio (no asset files)

**The pattern:** synthesize PCM samples into a `SoundData` → `love.audio.newSource(soundData, "static")` → `source:play()`.

```lua
local rate = 44100
local sd = love.sound.newSoundData(rate, rate, 16, 1)  -- 1 second, 16-bit mono
for i = 0, rate-1 do
  local t = i / rate
  local s = math.sin(2 * math.pi * 440 * t)            -- 440 Hz A
  local env = math.max(0, 1 - t / 0.5)                 -- quick decay envelope
  sd:setSample(i, s * env * 0.4)
end
local sfx = love.audio.newSource(sd, "static")
```

SoundData API: `love.sound.newSoundData(samples, sampleRate, bitDepth, channels)` (empty), `:setSample(i, value)`, `:getSample(i)`, `:getSampleCount()`, `:getSampleRate()`, `:getBitDepth()`, `:getChannelCount()`, `:getDuration()`. Blend multiple oscillators into one buffer for richer tones (chord, noise burst, "laser" = descending pitch sweep).

Source control: `src:play()/stop()/pause()`, `src:setLooping(true)`, `src:setVolume(v)`, `src:setPitch(p)`, `src:isPlaying()`. Global mixer: `love.audio.play(src)`, `love.audio.stop()`, `love.audio.pause()`, `love.audio.setVolume(v)`. `"static"` = small loaded-in-memory (SFX); `"stream"` = large/decoded in chunks (music) — use `"static"` for short procedural SFX. Generate continuous/ambient music by looping a synthesized buffer, or queue segments.

## Input

Keyboard: `love.keyboard.isDown("left","a","w",...)` → bool (held, poll in update); edge via `love.keypressed`. Named keys include `space return escape backspace tab delete up down left right home end pagedown pageup insert` plus letters `a`–`z`, digits, and `kp0`–`kp9` (numpad). Map layout with `love.keyboard.getScancodesFromKey(key)` / `love.keyboard.getKeyFromScancode(scancode)` (needed because physical vs. labelled keys differ by layout). Printable typing arrives in `love.textinput(text)`, not `keypressed`.

Mouse: `love.mouse.getPosition()` → `x,y`, `getX()/getY()`, `isDown(1,2,3)` (1=left, 2=right, 3=middle), `setPosition(x,y)` (may fail if pointer locked), `love.mouse.newCursor(imageData, hotx, hoty)` / `setCursor`.

Gamepad/joystick: `local jss = love.joystick.getJoysticks()`; `js:isGamepad()`. Gamepad constants: buttons `a b x y back start guide dpup dpdown dpleft dpright leftshoulder rightshoulder leftstick rightstick`; axes `leftx lefty rightx righty triggerleft triggerright`. Poll `js:isGamepadDown("a")`, `js:getGamepadAxis("leftx")`; or callbacks `love.gamepadpressed(js, button)`, `love.gamepadaxis(js, axis, value)`.

Touch: `love.touch.getTouches()` → list of touch ids, `love.touch.getPosition(id)` → x,y; callbacks `love.touchpressed(id, x, y, dx, dy, pressure)`.

## Math: random, noise, geometry

Random (seeded, reproducible; distinct from Lua's `math.random`):

```lua
love.math.setRandomSeed(seed)          -- deterministic runs
love.math.random()                     -- [0,1)
love.math.random(max)                  -- 1..max (int)
love.math.random(min, max)             -- min..max (int)
love.math.randomNormal(stddev, mean)   -- gaussian; default stddev 1, mean 0
```

Noise (Perlin/simplex, smooth 0–1-ish — for terrain, wobble, organic motion):

```lua
love.math.noise(x)                       -- 1D
love.math.noise(x, y)                    -- 2D
love.math.noise(x, y, z)                 -- 3D
love.math.noise(x, y, z, w)              -- 4D
-- offset coordinates over time to animate; scale coords for frequency
-- e.g. val = love.math.noise(worldX*0.02, worldY*0.02, time)
```

Geometry/geometry helpers: `love.math.triangulate({x1,y1,x2,y2,...})` → list of triangles (filling arbitrary concave polygons), `love.math.isConvex(points)`, `love.math.newBezierCurve(...points)` (`curve:evaluate(t)` → point, `getPointCount`), `love.math.newTransform(x,y,r,sx,sy)` (`transform:transformPoint(x,y)`), `love.math.gammaToLinear(r,g,b)` / `linearToGamma(r,g,b)`.

## Data & filesystem

Compression/encoding/hash (`love.data`) — `love.data.compress(type, str)` where `type` ∈ `"lz4" "zlib" "gzip" "deflate"`; `love.data.decompress(data, type, rawSize)`; `love.data.encode(format, "string"|"data", strOrData)` with `format` ∈ `"base64" "hex"`; `love.data.hash(hashfn, data)` with `"md5" "sha1" "sha256" ...`; `love.data.newData(...)` byte buffers. (No `love.data.lz4`/`phoenix` needed — that's the 12.x branch, not 11.5.)

Files: `love.filesystem.read(path)` → string (or nil), `love.filesystem.write(path, data, size)`, `love.filesystem.append`, `love.filesystem.load`, `love.filesystem.exists(path)`, `love.filesystem.getInfo(path)` → table with `type/size/modtime`. Paths are relative to the source or save dir (`love.filesystem.getSaveDirectory()`). For save games: `love.filesystem.write("save.dat", data)`. `love.filesystem.setRequirePath("?.lua;?/init.lua;lib/?.lua")` configures `require` — where `lib/` modules get found.

## Window, system, timer, misc

Window: `love.window.setMode(width, height, flags)` where flags table supports `fullscreen`, `vsync` (0/1), `resizable`, `minwidth`, `minheight`, `msaa`, `highdpi`, `x`, `y`; returns `success, displayindex, w, h`. `love.window.getWidth()/getHeight()/getDimensions()`, `love.window.setTitle("...")`, `love.window.setFullscreen(true)`. In draw space use `love.graphics.getWidth()/getHeight()`.

System: `love.system.getOS()` → `"Windows"|"OS X"|"Linux"|"Android"|"iOS"|"Web"`, `love.system.getProcessorCount()`, `love.system.openURL("https://...")`, `love.system.getClipboardText()/setClipboardText(str)`, `love.system.getPowerInfo()`.

Timer: `love.timer.getTime()` (absolute, differences only), `love.timer.getDelta()`, `love.timer.getFPS()`, `love.timer.getAverageDelta()`, `love.timer.sleep(s)`. Event: `love.event.quit()` / `love.event.push("quit")`.

Threads: `local th = love.thread.newThread(sourceString, ...)` then `th:start(...)`, `th:getError()`; message passing via `love.thread.getChannel(name)` with `channel:push(v)` / `channel:pop()` / `channel:demand()` / `channel:clear()`. Use only for genuinely long work (asset/save generation) — premature threading is a trap.

## Physics (optional)

Box2D wrapper — only when a real rigid-body sim is required; otherwise skip and animate manually.

```lua
local world = love.physics.newWorld(0, 980, true)     -- gravity x,y, allowSleep
local body = love.physics.newBody(world, x, y, "dynamic")   -- "static"|"dynamic"|"kinematic"
local shape = love.physics.newRectangleShape(w, h)    -- or newCircleShape(r) / newPolygonShape(...)
local fix  = love.physics.newFixture(body, shape, 1)
fix:setFriction(0.3); fix:setRestitution(0.2)
-- in update: world:update(dt)
-- read: body:getPosition(), body:getAngle(); act: body:setLinearVelocity(vx,vy), body:applyLinearImpulse(ix,iy)
```

## Gotchas

- **Colors are 0..1 floats** — the single most common 11.x bug. `setColor(255,0,0)` silently burns out.
- **Angles are radians**, and 0 faces **right** (not up). Convert with `math.rad`/`math.deg` as needed.
- **`dt` everywhere.** Un-scaled movement doubles/triples speed at high FPS. Also avoid relying on `getFPS` for logic.
- **Create assets once**, in `love.load` or lazily, and reuse. Building `ImageData`/fonts/Sources every frame floods the GC.
- **`push`/`pop` around transforms** — leaks accumulate otherwise and one offset corrupts everything after it.
- **Draw from state only.** Referencing an input event inside `draw` causes 1-frame flicker.
- **`love.graphics.getWidth` may differ from `love.window.getWidth`** under `highdpi`; use the graphics ones for drawing bounds.
- **`textinput` vs `keypressed`** for characters — letters/unicode come through `love.textinput`, not `keypressed`.
- **`printf` needs an explicit width limit** or it won't wrap.
- **Canvas default = window pixels**; if you resize the window, recreate/resize canvases in `love.resize`.
- **`love.math.random` is not `math.random`** — for reproducible tests set the LÖVE seed, not Lua's.
- **No asset files exist in this repo** by design. If you're tempted to load a `.png`/`.wav`/`.ttf`, generate the equivalent in code instead (see the procedural sections). This is a hard rule.
- **11.5 vs 12.x:** `love.data.lz4`, `phoenix` videos, the Noto default font, and some renames are the 12.x line. This repo is **11.5**; don't reach for them.
