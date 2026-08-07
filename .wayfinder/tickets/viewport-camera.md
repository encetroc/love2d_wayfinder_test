Part of #1

## Question

What are the viewport, tile geometry, and camera decisions for the top-down tiled view?

Decide: render resolution (and window scaling to fit the screen), tile size in pixels, how the world maps to the screen (simple offset camera following the player through a scrolling floor — no isometric projection), and any config constants that downstream render/gameplay modules read. The tile grid is the ground truth for collision and rooms; the camera is just a scroll offset.

Also pick a seed-friendly debug default (e.g. fixed window, deterministic first seed) so runs render identically across restarts.
