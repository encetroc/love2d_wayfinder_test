Part of #1

## Question

Which procedural room-generation algorithm fits a top-down tiled, single-floor roguelike shooter built with seeded RNG? (research — resolved by a /research subagent against primary sources, e.g. the RogueBasin / grid-based-dungeon literature and the random-dungeon PCG canon.)

Compare candidate approaches — BSP tree, grid-of-rooms with connecting corridors, cellular automata — for: a compact single floor, guaranteed connectivity, and a natural home for a single exit/boss room. Recommend one with a concrete seeded generation recipe (deterministic given a seed) and note any LÖVE-relevant gotchas. Output a written finding saved as a Markdown note in the repo.

Blocks the floor-representation and run-lifecycle tickets.
