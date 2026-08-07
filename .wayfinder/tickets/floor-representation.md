Part of #1

## Question

What is the data model for one floor, and how does seeded RNG flow through it?

Decide: how a floor is represented (tile grid + room list + connections + spawn points + exit location), what the seed controls (layout, pickup placement, enemy spawns), and the module (`lib/seeded.lua`?) that wraps `love.math.random`/seeding so any run can be reproduced and debugged. Must be friendly to small-step building: a floor object that map-gen, combat, and enemies all read from.

Blocked by the room-generation ticket (its algorithm determines this shape).
