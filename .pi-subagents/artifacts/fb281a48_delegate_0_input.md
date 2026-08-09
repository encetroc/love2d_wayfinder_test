# Task for delegate

Look at these 7 image files (gameplay screenshots of the pixel-art arcade game "Antecrypt" by PUNKCAKE Délicieux) and write a detailed visual-style specification we can use to replicate the look in another LÖVE game:

/tmp/antecrypt_style/ss_bd0d0526476e218404691fd76872659f6737d7e9.jpg
/tmp/antecrypt_style/ss_facbe4efe7b5a7bbd67da6f21807b7ac321e4792.jpg
/tmp/antecrypt_style/ss_1c39e4de214b1ad62773108e2bdec05deaf749f9.jpg
/tmp/antecrypt_style/ss_87c69fe82b6e25ef1d610ddb8382d77a0b59e7cb.jpg
/tmp/antecrypt_style/ss_f74dd627420ffe97021f485e516d9d51a588d89f.jpg
/tmp/antecrypt_style/ss_40e9bf679e4a272061a53a08ef3b0ba73fcf8c1d.jpg
/tmp/antecrypt_style/capsule.jpg

Report on, specifically and concretely:
1. Background and environment: is the playfield black with dark-green floor/grid lines? Describe the ground texture/grid pattern of the arena, border/walls (any scanline or CRT effect? vignette?).
2. Palette: the exact hues you can identify — the green(s) used for the world vs entities (players/projectiles/monsters), any accent colors (white, yellow, red, cyan) and where they appear.
3. Entities: describe the PLAYER character (shape/size/color) and 2-3 enemy/monster archetypes you can distinguish (shapes, colors, glow). Are sprites small (e.g. 8-16px) with neon outlines/glow?
4. Projectiles/effects: what do the laser beams / bullets / explosions / sparks look like? (bright white cores? additive glow? colored tracers? particle bursts?)
5. UI/HUD: what appears on screen — score, timer, level, HP, crosshair/reticle (the game has a bouncing crosshair — describe it), menus styling, font style.
6. Overall composition and "feel": internal resolution estimate (pixel size, how chunky are the pixels?), lighting style (dark ambient + small bright glowing elements?), the CRT/terminal "hard-drive" theming cues.
7. Anything distinctive — scanlines, screen shake, flash overlays, chromatic effects, scanline flicker.

Be specific with hex colors where you can see them. This spec will be used to replicate the visual style, so bias toward concrete, implementable detail over prose.