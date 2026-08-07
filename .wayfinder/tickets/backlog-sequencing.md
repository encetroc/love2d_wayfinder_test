Part of #1

## Question

Given all resolved decisions, what is the ordered implementation backlog — the sequence of small, runnable, verifiable build tickets that will execute this plan?

This is the map's final output artifact (the plan-to-spec destination's payoff): each implementation ticket scoped to one subsystem, small enough for a single session, runnable and verifiable on its own, ordered so that each step builds on a working state (no big-bang integration). Backport any architectural constraints from the architecture ticket so the backlog enforces the anti-monolith rule.

Blocked by the architecture, run-lifecycle, and HUD/game-feel tickets (and transitively the rest).
