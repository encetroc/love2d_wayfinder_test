-- lib/map.lua — floor generation (B4).
-- Grid-of-rooms + connecting corridors (RogueBasin grid method) with a
-- reserved farthest EXIT cell and spanning-tree corridors, per
-- docs/research/room-generation.md; data model per docs/floor-model.md.
-- EVERY random draw flows through world.seeded — identical seed => identical
-- floor. love.math.noise is never used for layout. Connectivity is
-- guaranteed by construction AND asserted fail-loud (flood-fill from spawn)
-- at generation time.
--
-- Contract: load/update/draw(world, dt) + optional keypressed(world, key).
-- load() wires world.map = map and generates the floor. main.lua registers
-- seeded before map, so the RNG is already seeded when we generate.

local KIND = { WALL = "wall", FLOOR = "floor", EXIT = "exit" }

local CELL = 5 -- grid cell in tiles: 40x30 map -> 8x6 = 48 candidate cells (docs/floor-model.md)

local map = {
  floor = nil, -- generated floor: { grid, rooms, spawn, exit } (data only)
}

local seedStr -- for the assert message; set by map.generate(), read by generateFloor

-- --- floor generation -----------------------------------------------------

local function generateFloor(rng)
  local MAPW, MAPH = map.MAPW, map.MAPH
  local CELLS_X, CELLS_Y = MAPW / CELL, MAPH / CELL

  local grid = {}
  for ty = 1, MAPH do
    grid[ty] = {}
    for tx = 1, MAPW do
      grid[ty][tx] = KIND.WALL
    end
  end

  local used = {} -- "cx,cy" -> true
  local function key(c) return c[1] .. "," .. c[2] end

  local function pickFreeCell()
    local free = {}
    for cy = 1, CELLS_Y do
      for cx = 1, CELLS_X do
        if not used[cx .. "," .. cy] then free[#free + 1] = { cx, cy } end
      end
    end
    return free[rng.int(#free)]
  end

  -- 1) spawn room: random cell
  local spawnCell = pickFreeCell()
  used[key(spawnCell)] = true

  -- 2) exit cell: farthest Manhattan from spawn among unused (deterministic,
  --    no extra RNG — guarantees the exit is meaningfully deep)
  local exitCell, best = nil, -1
  for cy = 1, CELLS_Y do
    for cx = 1, CELLS_X do
      if not used[cx .. "," .. cy] then
        local d = math.abs(cx - spawnCell[1]) + math.abs(cy - spawnCell[2])
        if d > best then
          best = d
          exitCell = { cx, cy }
        end
      end
    end
  end
  used[key(exitCell)] = true

  local rooms = {}

  local function placeRoom(cell, id)
    local w = rng.int(2, CELL - 1) -- room fills part of its 5x5 cell (no overlaps possible)
    local h = rng.int(2, CELL - 1)
    -- offset in [1, CELL-w]: a 1..CELL-w offset keeps the room strictly inside
    -- tile rows/cols 1..40 x 1..30 (offset 0 would put it at row/col 0 — an
    -- off-map row that crashed gen #2+; also avoids overflow past MAPW/MAPH)
    local x = (cell[1] - 1) * CELL + rng.int(1, CELL - w)
    local y = (cell[2] - 1) * CELL + rng.int(1, CELL - h)
    for ty = y, y + h - 1 do
      for tx = x, x + w - 1 do
        grid[ty][tx] = KIND.FLOOR
      end
    end
    local room = {
      id = id,
      rect = { x = x, y = y, w = w, h = h },
      connections = {},
    }
    rooms[#rooms + 1] = room
    return room
  end

  -- 3) room order: spawn first, then normal rooms, exit LAST (chain end).
  --    Count is 3..8 and includes spawn + exit.
  local count = rng.int(3, 8)
  local spawnRoom = placeRoom(spawnCell, 1)
  spawnRoom.spawn = true
  local exitRoom
  for i = 2, count - 1 do
    -- B9: mark the picked cell used BEFORE placing, exactly like spawn/exit
    -- do — the caller used to skip this, so a later pickFreeCell could reuse
    -- the same 5x5 cell and the two rooms would OVERLAP (rects share tiles,
    -- roomAt became ambiguous — broke B9's "pickup inside ITS room"
    -- guarantee and would've bitten B10's room tracking too). Latent since
    -- B4; the connectivity assert can't see it (both rooms stay reachable).
    local c = pickFreeCell()
    used[key(c)] = true
    placeRoom(c, i)
  end
  exitRoom = placeRoom(exitCell, count)
  exitRoom.exit = true

  -- 4) corridors: spanning tree by construction — connect each room to the
  --    immediately previous one (L/Z elbow through room centers).
  local function corridor(a, b)
    local ax, ay = a.rect.x + math.floor(a.rect.w / 2), a.rect.y + math.floor(a.rect.h / 2)
    local bx, by = b.rect.x + math.floor(b.rect.w / 2), b.rect.y + math.floor(b.rect.h / 2)
    if rng.pick({ "h", "v" }) == "h" then
      local xa, xb = math.min(ax, bx), math.max(ax, bx)
      for tx = xa, xb do grid[ay][tx] = KIND.FLOOR end
      local ya, yb = math.min(ay, by), math.max(ay, by)
      for ty = ya, yb do grid[ty][bx] = KIND.FLOOR end
    else
      local ya, yb = math.min(ay, by), math.max(ay, by)
      for ty = ya, yb do grid[ty][ax] = KIND.FLOOR end
      local xa, xb = math.min(ax, bx), math.max(ax, bx)
      for tx = xa, xb do grid[by][tx] = KIND.FLOOR end
    end
    a.connections[#a.connections + 1] = b.id
    b.connections[#b.connections + 1] = a.id
  end
  for i = 2, #rooms do
    corridor(rooms[i - 1], rooms[i])
  end

  -- 5) spawn + exit tiles
  local sTx = spawnRoom.rect.x + math.floor(spawnRoom.rect.w / 2)
  local sTy = spawnRoom.rect.y + math.floor(spawnRoom.rect.h / 2)
  local eTx = exitRoom.rect.x + math.floor(exitRoom.rect.w / 2)
  local eTy = exitRoom.rect.y + math.floor(exitRoom.rect.h / 2)
  grid[sTy][sTx] = KIND.FLOOR -- spawn tile is walkable floor; marked on the room
  grid[eTy][eTx] = KIND.EXIT

  local floor = {
    grid = grid,
    rooms = rooms,
    spawn = { room = 1, tx = sTx, ty = sTy },
    exit = { room = count, tx = eTx, ty = eTy, boss = true },
  }

  -- 6) connectivity assert — fail loud (docs/research/room-generation.md step 6)
  do
    local seen = {}
    local stack = { { sTx, sTy } }
    seen[sTy .. "," .. sTx] = true
    while #stack > 0 do
      local c = table.remove(stack)
      for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
        local nx, ny = c[1] + d[1], c[2] + d[2]
        if nx >= 1 and nx <= MAPW and ny >= 1 and ny <= MAPH and not seen[ny .. "," .. nx] then
          local k = grid[ny][nx]
          if k == KIND.FLOOR or k == KIND.EXIT then
            seen[ny .. "," .. nx] = true
            stack[#stack + 1] = { nx, ny }
          end
        end
      end
    end
    for _, r in ipairs(rooms) do
      local reached = false
      for ty = r.rect.y, r.rect.y + r.rect.h - 1 do
        for tx = r.rect.x, r.rect.x + r.rect.w - 1 do
          if seen[ty .. "," .. tx] then reached = true break end
        end
        if reached then break end
      end
      assert(reached,
        string.format("connectivity: room %d not reachable from spawn (world seed %s)", r.id, tostring(seedStr)))
    end
  end

  return floor
end

-- --- module contract ------------------------------------------------------

function map.load(world)
  world.map = map
  map.TILE = world.TILE
  map.MAPW = world.WORLD_W / world.TILE -- 40 tiles
  map.MAPH = world.WORLD_H / world.TILE -- 30 tiles
  map.generate(world)
end

-- Regenerate from the CURRENT rng state (callers re-seed world.seeded first).
function map.generate(world)
  seedStr = world.seed -- upvalue for the assert message
  map.floor = generateFloor(world.seeded)

  -- one SpriteBatch per tile type, built once per generation
  map.wallBatch = love.graphics.newSpriteBatch(world.assets.images.wall, map.MAPW * map.MAPH)
  map.floorBatch = love.graphics.newSpriteBatch(world.assets.images.floor, map.MAPW * map.MAPH)
  local TILE = map.TILE
  for ty = 1, map.MAPH do
    for tx = 1, map.MAPW do
      local k = map.floor.grid[ty][tx]
      local px, py = (tx - 1) * TILE, (ty - 1) * TILE
      if k == KIND.WALL then
        map.wallBatch:add(px, py)
      elseif k == KIND.FLOOR or k == KIND.EXIT then
        map.floorBatch:add(px, py)
      end
    end
  end
end

function map.update()
end

-- B5+: native-scale, camera-relative draw (the canvas IS the viewport).
-- The B4 whole-floor fit-preview is retired now that the camera scrolls.
function map.draw(world)
  local f = map.floor
  if not f or not world.camera then return end
  local TILE = map.TILE

  world.camera.apply() -- world-space content below; camera.pop() at the end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(map.wallBatch, 0, 0)
  love.graphics.draw(map.floorBatch, 0, 0)

  -- exit portal: the Antecrypt "white hard-drive monolith" focal — white-hot
  -- core + a wider pale-green halo (B6.1)
  local e = f.exit
  love.graphics.setBlendMode("add")
  love.graphics.setColor(0.35, 1.00, 0.50, 0.5)
  love.graphics.draw(world.assets.images.glow, (e.tx - 1) * TILE - 6, (e.ty - 1) * TILE - 6, 0, 1.8, 1.8)
  love.graphics.setColor(1, 1, 1, 0.9)
  love.graphics.draw(world.assets.images.glow, (e.tx - 1) * TILE, (e.ty - 1) * TILE)
  love.graphics.setBlendMode("alpha")

  if world.debug then
    -- spawn marker + room ids (dev readout, world space, restyled B6.1)
    local s = f.spawn
    love.graphics.setColor(0.35, 1.00, 0.55, 0.9)
    love.graphics.rectangle("line", (s.tx - 1) * TILE + 2, (s.ty - 1) * TILE + 2, 12, 12)
    love.graphics.setColor(0.35, 0.85, 0.50, 0.6)
    for _, r in ipairs(f.rooms) do
      local cx = (r.rect.x + r.rect.w / 2) * TILE
      local cy = (r.rect.y + r.rect.h / 2) * TILE
      local tag = tostring(r.id)
      if r.spawn then tag = tag .. " S" end
      if r.exit then tag = tag .. " E" end
      love.graphics.print(tag, cx, cy)
    end
  end
  world.camera.pop()
end

-- Debug: R re-renders the floor from the SAME seed -> identical layout
-- (B4 verify "identical re-render on R"). B10's run module later takes over
-- R for full-run replay.
function map.keypressed(world, key)
  if world.debug and key == "r" then
    world.seeded.setSeed(world.seed)
    map.generate(world)
  end
end

-- --- queries (read the generated floor; nothing re-derives layout) --------

function map.isWalkable(tx, ty)
  local f = map.floor
  if not f or tx < 1 or ty < 1 or tx > map.MAPW or ty > map.MAPH then return false end
  local k = f.grid[ty][tx]
  return k == KIND.FLOOR or k == KIND.EXIT
end

-- pixel-space walkability (continuous-movement collision helper)
function map.isWalkablePx(x, y)
  return map.isWalkable(math.floor(x / map.TILE) + 1, math.floor(y / map.TILE) + 1)
end

-- tile kind from PIXEL coords (continuous world over discrete grid)
function map.tileAt(x, y)
  return map.tileAtT(math.floor(x / map.TILE) + 1, math.floor(y / map.TILE) + 1)
end

function map.tileAtT(tx, ty)
  if tx < 1 or ty < 1 or tx > map.MAPW or ty > map.MAPH then return KIND.WALL end
  return map.floor.grid[ty][tx]
end

-- which room is a tile in (nil if corridor/wall)
function map.roomAt(tx, ty)
  for _, r in ipairs(map.floor.rooms) do
    local rc = r.rect
    if tx >= rc.x and tx < rc.x + rc.w and ty >= rc.y and ty < rc.y + rc.h then
      return r
    end
  end
  return nil
end

return map