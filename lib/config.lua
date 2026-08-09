-- lib/config.lua — single constants table (B1).
-- Downstream render + gameplay modules read these. The window constants are
-- mirrored into LÖVE itself by conf.lua, which requires this table (one
-- source of truth for every number).
-- Sources: docs/floor-model.md (tile/world geometry), docs/viewport-camera.md
-- (viewport/window policy).

local config = {
  TITLE = "Wayfinder",

  -- Floor geometry
  TILE = 16,  -- px per tile
  MAPW = 640, -- world width  px (40 tiles)
  MAPH = 480, -- world height px (30 tiles)

  -- Viewport: base-res render target (3:2)
  VIEW_W = 480,
  VIEW_H = 360,

  -- Default window (= viewport x2, nearest-upscaled, docs/viewport-camera.md)
  WIN_W = 960,
  WIN_H = 720,

  -- Seed-friendly debug default: fixed window, reproducible first run.
  DEBUG_SEED = "dev",
}

return config