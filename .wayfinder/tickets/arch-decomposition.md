Part of #1

## Question

How should this game be decomposed so that no single file or module becomes an unmaintainable monolith — directly serving the "avoid large crash-prone code" goal?

Decide the `lib/` module split (e.g. `lib/map.lua`, `lib/player.lua`, `lib/enemy.lua`, `lib/combat.lua`, `lib/assets.lua`, `lib/seeded.lua`, ...), the responsibilities of `main.lua` (slim thin: create modules, delegate update/draw), and the rule that every subsystem is a self-contained module with its own love.load/update/draw hooks. Confirm the "one subsystem per runnable increment" framing so the implementation backlog can be sequenced from it.

➡️ Sketch the module list and the load/update/draw flow; get them approved before the rest of the map depends on it.
