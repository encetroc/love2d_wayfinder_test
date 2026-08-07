# Procedural audio scope

> Repo note — GitHub issue #10 design map. LÖVE 11.5, native-only, no external audio files (hard repo rule).

## Decision (summary)

- **Keep (sfx set):** shoot, enemy-hit/death, pickup, hurt/player-death — plus a reuse/derived enemy-projectile shoot (no extra synthesis cost). That is the **minimum believable** procedural SFX set.
- **CUT:** floor ambience AND music. Both are implementable in LÖVE 11.5, but they are the most speculative, least essential, highest-burden items in a scope-controlled roguelike, and the map's standing preference is to cut questionable scope. Neither is required for a playable, self-consistent shooter. Defer as a low-priority later addition.

This fully satisfies the "procedural audio scope" deliverable for a single-floor top-down tiled roguelike shooter while keeping the destination lean.

---

## Findings

1. **The SoundData-synthesis + `newSource("static")` pattern is confirmed and is the canonical LÖVE approach.** Build PCM samples into a `SoundData`, wrap in a `Source` created from that `SoundData`, then `play()` it. No file loading of any kind is involved. The repo's own pinned reference documents the exact pattern:

   ```lua
   local rate = 44100
   local sd = love.sound.newSoundData(rate, rate, 16, 1)  -- 1s, 16-bit mono
   for i = 0, rate-1 do
     local t = i / rate
     local s = math.sin(2 * math.pi * 440 * t)   -- 440 Hz A (sine)
     local env = math.max(0, 1 - t / 0.5)        -- quick decay envelope
     sd:setSample(i, s * env * 0.4)
   end
   local sfx = love.audio.newSource(sd, "static")
   ```

   [LÖVE reference, "Procedural audio (no asset files)"](https://love2d.org/wiki/Procedural_Audio) and repo `REFERENCE.md`.

2. **`love.sound.newSoundData(samples, rate, bits, channels)` — exact signature.** The wiki spec: `samples` (total samples), `rate` (samples/second, default 44100), `bits` (8 or 16, default 16), `channels` (1 mono or 2 stereo, default 2). For one-shot SFX use **mono** (`1`); for a synthesized stereo ambience/music you would use `2`. [love.sound.newSoundData](https://love2d.org/wiki/love.sound.newSoundData)

3. **`SoundData:setSample(i, sample)` — sample index and value domain.** Index `i` starts at **0** and is an integer 0..getSampleCount()-1. The value is a **normalized float in `-1.0 .. 1.0`**, representing the PCM sample amplitude. This `(i, value)` variant (with the value-floats domain) is available since **LÖVE 11.0** — exactly the 11.5 line we target. [SoundData:setSample](https://love2d.org/wiki/SoundData:setSample), corroborated by the exported wiki mirror (W3cubDocs).

4. **`Source` created from a `SoundData` is always `"static"`.** The `love.audio.newSource` wiki states unequivocally: *"Sources created from SoundData are always static."* A static source keeps the whole audio decoded in memory — the intended mode for short SFX. For SFX you can pass the `SoundData` alone (no type arg needed) or pass `"static"` explicitly as in the reference pattern. [love.audio.newSource](https://love2d.org/wiki/love.audio.newSource)

5. **`"static"` vs `"stream"` guidance.** The `SourceType` wiki/audio tutorial: use `stream` for large music files (decoded in chunks, streamed from disk or queued), and `static` for *all short sound effects* (whole thing in memory). Since everything here is synthesized (no disk stream exists and none is desired), every source is `static`. **Important implication:** even "music" would be a `static` looping buffer, not a `stream` source — there is no file to stream. [SourceType](https://love2d.org/wiki/SourceType), [Tutorial:Audio](https://love2d.org/wiki/Tutorial:Audio)

6. **Source control for reliable one-shots.** `src:play()/stop()/pause()`, `src:setPitch(p)`, `src:setVolume(v)`, `src:setLooping(true)`, `src:isPlaying()`. Global mixer: `love.audio.play(source, ...)` (play and mix one or more), `love.audio.stop()`, `love.audio.setVolume(v)`. **Gotcha:** to replay a one-shot that is still playing, call `src:stop()` before `src:play()`, or use a small pool of pre-created static sources per sfx type — standing repo guidance is to "create assets once, in `love.load` or lazily, and reuse." [love.audio.play](https://love2d.org/wiki/love.audio.play), repo `REFERENCE.md`.

7. **No external audio asset files are used — confirmed hard rule.** The repo reference states: *"No asset files exist in this repo by design… If you're tempted to load a `.png`/`.wav`/`.ttf`, generate the equivalent in code instead (see the procedural sections). This is a hard rule."* All audio is synthesized in code via `SoundData` + `newSource`; no `.wav`/`.ogg`/`.mp3` ever committed. (The wiki's `newSource` *file-path* overload exists but is simply never used here.) [repo `REFERENCE.md` gotchas]

---

## Recommended SFX set (keep)

| SFX | Synthesis recipe (all in code) | Src |
| --- | --- | --- |
| Shoot / player weapon | Short (0.08–0.15 s) **descending pitch sweep** ("laser") — sine/square with frequency ramping down, fast decay envelope; optional tiny noise transient at attack. | love.sound.newSoundData + setSample sweep |
| Enemy-hit / enemy-death | Short **noise burst** with fast decay (impact) — mix a little pitched tone with filtered noise; death can be slightly longer/lower than hit. Distinguish hit (short) vs death (longer, lower). | setSample with random/noise samples |
| Pickup | **Rising chiptune arpeggio** (2–3 ascending tones, e.g. square/sine 3 quick notes) — classic "collect" cue. | setSample sequential tones |
| Hurt / player-death | **Low descending tone** (hurt) and a **longer noise + low sweep explosion** (death). Player-death should be the most prominent. | setSample sweep + noise |

**Optional, zero extra synthesis cost (recommend keep if trivial):** **enemy-projectile shoot** — reuse the shoot recipe with a pitched-down or pitch-varied variant (different frequency). Because every sfx shares one ~30-line synthesis helper, adding a derived variant is ~free; but it is **not** part of the strict minimum, so it can also be deferred.

What is intentionally **excluded**: `enemy detection/alarm` stingers, `cash/heartbeat` loops, `footstep/`step` variations, UI minor clicks — all optional polish, not minimum scope, and de-scoped.

---

## Cut decision: ambience & music (CUT)

- **Why it's cut, not kept:** the destination map's stated standing preference is to **cut questionable scope**. Music/ambience is the single most speculative, least essential item on the list — it carries no gameplay information and can be added post-hoc without touching any core system.
- **Why it's not "unsupported":** LÖVE 11.5 *can* do it — synthesize a longer buffer and loop it with `src:setLooping(true)` on a `static` source, or generate a continuous ambient buffer. So this is purely a **scope** decision, not a technical constraint.
- **Resolution:** CUT floor ambience and music from destination scope. Add a **deferred follow-up item** ("optional: procedural music bed / floor ambience loop via synthesized looping `static` source") so it's not lost, but it is out of the v1 design map.
- **Reasoning summary:** (a) standing cut-questionable-scope preference; (b) no gameplay/information value; (c) highest synthesis-design burden (tempo/harmony/bed design) for lowest payoff in a tiled shooter; (d) trivially addable later as a looping static buffer (mono→stereo by setting `channels=2`), so deferring costs nothing.

---

## Concrete pattern (final, LÖVE 11.5)

```lua
-- audio.lua — synthesize once in love.load, reuse
local RATE = 44100
local function makeTone(dur, freqStart, freqEnd, vol, wave)
  local n  = math.floor(dur * RATE)
  local sd = love.sound.newSoundData(n, RATE, 16, 1)      -- n samples, 16-bit mono
  for i = 0, n-1 do
    local t    = i / RATE
    local prog = i / n
    local f    = freqStart + (freqEnd - freqStart) * prog            -- sweep
    local s    = math.sin(2*math.pi*f*t)                             -- sine
    if wave == "square" then s = s > 0 and 1 or -1 end               -- square tone
    local env  = math.max(0, 1 - prog) * vol                         -- decay envelope
    sd:setSample(i, math.max(-1, math.min(1, s * env)))              -- clamp -1..1
  end
  return love.audio.newSource(sd)   -- "static" by definition (from SoundData)
end

function love.load()
  shootSfx  = makeTone(0.10, 900, 200, 0.5, "square")   -- descending laser
  hitSfx    = makeTone(0.08, 500, 300, 0.5, "sine")     -- enemy hit
  deathSfx  = makeTone(0.30, 300, 60,  0.7, "square")   -- enemy/player death, low sweep
  pickupSfx = makeTone(0.18, 600, 900, 0.5, "square")   -- rising pickup
  hurtSfx   = makeTone(0.25, 250, 90,  0.6, "sine")     -- hurt
end

-- play a one-shot safely (restart even if still playing)
local function playOnce(src)
  src:stop()
  src:play()
end
```

No `love.filesystem`, no `love.sound.newSoundData(filepath)`, no external assets. All `static` (auto from SoundData).

---

## Sources

**Kept:**

- repo `REFERENCE.md` — "Procedural audio (no asset files)" + gotchas — the repo's pinned single source of truth (11.5, native-only, no-assets hard rule); authoritative for the exact pattern and the "always static from SoundData / reuse in love.load" guidance.
- [love.sound.newSoundData](https://love2d.org/wiki/love.sound.newSoundData) — primary API for `newSoundData(samples, rate, bits, channels)`.
- [SoundData:setSample](https://love2d.org/wiki/SoundData:setSample) — primary API confirming `(i, value)` float `-1..1`, index from 0, since 11.0 (corroborated by W3cubDocs exported mirror).
- [love.audio.newSource](https://love2d.org/wiki/love.audio.newSource) — primary API: sources from SoundData are always `static`.
- [SourceType](https://love2d.org/wiki/SourceType) + [Tutorial:Audio](https://love2d.org/wiki/Tutorial:Audio) — `static` (short SFX, in-memory) vs `stream` (music from file); informs the cut/keep music reasoning (music here would be a looping `static` buffer, no file exists).

**Dropped:**

- W3cubDocs / TypeError mirrors of LÖVE docs — used only as corroboration of primary wiki content; not cited as authoritative since the official wiki bot-gate blocked direct fetch (content captured via search cache instead).
- Generic "procedural audio" blog/tutorial pages — not needed; not primary.

---

## Gaps

- **Direct fetch of love2d.org wiki pages was blocked** by a bot/security check; authoritative content was captured via search-result cache of the primary wiki plus official-mirror corroboration. The exact signatures are unambiguous and cross-confirmed, but if absolute fidelity to specific wiki wording is required, re-verify by opening the pages interactively.
- **Waveform "sound quality" is not measurable in a doc** — the recipes above are structurally correct but not auditioned. Final tuning (frequencies, durations, volume balance, exact noise recipe) should be validated in-engine during implementation; treat the table as the *scope contract*, not finished art.
- **Source count/polyphony ceiling** is not specified — worth a follow-up decision if many simultaneous one-shots occur (cap concurrent sources or reuse a pool; OpenAL via `love.audio` has practical per-source limits). Suggested next step: a quick engine spike (`love.load` synthesize + fire 20 overlapping one-shots) to confirm no clipping/throttling on target hardware.
