Part of #1

## Question

How are the procedural tile & sprite assets generated in code, to deliver the flat-geometric + neon visual style on a GBC-Zelda-style top-down tile grid? (research — resolved by a /research subagent against the love2d skill's REFERENCE.md and LÖVE API docs.)

Determine the concrete pattern per artifact (from the love2d skill's decision line): ImageData + setPixel for tile sprites, Image/Mesh/SpriteBatch for rendering many tiles, Canvas for off-screen composition, and how flat shapes + neon glow read at small tile sizes. Propose a small set of procedurally-generated tile/sprite primitives (floor tile, wall tile, player sprite, each enemy archetype's sprite, projectile) with the module that owns generation (likely `lib/assets.lua`). Output a written finding + a working prototype note.
