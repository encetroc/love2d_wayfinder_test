Part of #1

## Question

How does a single run start, progress, and end — the permadeath run lifecycle?

Decide: run start (new seeded floor), the in-run state machine, the win condition (reach the exit/boss room → floor cleared) and loss condition (HP to 0 → permadeath, full restart), and how a new run is seeded. This glues the floor, combat, and enemies into a coherent loop and is the module/sequence layer that makes `main.lua` thin.

Blocked by the floor-representation, combat/weapons, and enemy-ai tickets.
