-- conf.lua — LÖVE window configuration (B1). Runs before love.* is ready;
-- only require works here, hence the require of the constants table.
-- Policy per docs/viewport-camera.md: fixed 960x720 default window, dev
-- fullscreen off, resizable + letterboxed (scale math lives in main.lua).
local config = require("lib.config")

function love.conf(t)
  t.version = "11.5"

  t.window.title    = config.TITLE .. " — B1 shell"
  t.window.width    = config.WIN_W
  t.window.height   = config.WIN_H
  t.window.resizable = true
  t.window.minwidth  = config.VIEW_W -- never smaller than the base canvas
  t.window.minheight = config.VIEW_H
  t.window.vsync     = 1
  t.window.fullscreen = false
end