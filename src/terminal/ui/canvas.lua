--- A canvas using Unicode Braille characters for TUI pixel graphics.
-- Each cell is 2 pixels wide, 4 pixels tall (8 dots per braille character).
--
-- Pixel coordinates are 0-based. The origin (0, 0) is at the top-left corner,
-- with x increasing to the right and y increasing downward.

local t = require "terminal"
local utils = t.utils
local position = t.cursor.position



-- Dot bit positions within a braille cell:
--   col 0 (left):  row 0=0x01, row 1=0x02, row 2=0x04, row 3=0x40
--   col 1 (right): row 0=0x08, row 1=0x10, row 2=0x20, row 3=0x80
-- Row 0 is the TOP pixel in the cell.
local DOT_BIT = {
  [0] = { [0] = 0x01, [1] = 0x02, [2] = 0x04, [3] = 0x40 },
  [1] = { [0] = 0x08, [1] = 0x10, [2] = 0x20, [3] = 0x80 },
}



-- Encode a braille dot-pattern index (0–255) as a UTF-8 string.
-- U+2800+i: byte1=0xE2, byte2=0xA0+(i>>6), byte3=0x80+(i&0x3F)
local function braille(i)
  return string.char(0xE2, 0xA0 + (i >> 6), 0x80 + (i & 0x3F))
end



-- Cells store full UTF-8 braille characters, so rendering is a bare table.concat.
-- Draw path is a single flat table lookup keyed by current_char .. col_byte .. row_byte.
--
-- Flat LUTs keyed by: current_utf8_char (3 bytes) .. col_byte .. row_byte (2 bytes)
-- 256 cell states × 2 cols × 4 rows = 2048 entries each.
local SET_LUT   = {}
local UNSET_LUT = {}

for i = 0, 255 do
  local ch = braille(i)
  for col = 0, 1 do
    for row = 0, 3 do
      local bit = DOT_BIT[col][row]
      local key = ch .. string.char(col, row)
      SET_LUT[key]   = braille(i | bit) -- TODO: fix this for all Lua versions
      UNSET_LUT[key] = braille(i & ~bit)
    end
  end
end



local BLANK   = braille(0)    -- U+2800, all dots off
local FILLED  = braille(0xFF) -- U+28FF, all dots on



local Canvas = utils.class()



--- Create a new canvas.
-- @tparam table opts
-- @tparam number opts.width   Width in display columns (each column is 2 pixels wide)
-- @tparam number opts.height  Height in display rows (each row is 4 pixels tall)
-- @tparam[opt=false] boolean opts.invert  If true, cleared cells are fully lit instead of empty
function Canvas:init(opts)
  opts = opts or {}
  assert(opts.width and opts.height, "width and height must be provided")
  if opts.width <= 0 or opts.height <= 0 then
    error("canvas dimensions must be positive")
  end

  self.cols   = opts.width
  self.rows   = opts.height
  self.px_w   = opts.width * 2
  self.px_h   = opts.height * 4
  self._blank = opts.invert and FILLED or BLANK

  self._seq_between = position.down_seq(1) .. position.left_seq(self.cols)
  self._seq_return  = position.left_seq(self.cols) .. position.up_seq(self.rows - 1)

  self.cells = {}
  for r = 1, self.rows do
    local row = {}
    for c = 1, self.cols do
      row[c] = self._blank
    end
    self.cells[r] = row
  end
end



--- Set (illuminate) a pixel.
-- Coordinates are 0-based; origin (0, 0) is at the top-left.
-- @tparam number x pixel column, 0-based, left to right
-- @tparam number y pixel row, 0-based, top to bottom
function Canvas:set(x, y)
  local cell_col = math.floor(x / 2) + 1
  local cell_row = math.floor(y / 4) + 1
  local c = self.cells[cell_row][cell_col]
  self.cells[cell_row][cell_col] = SET_LUT[c .. string.char(x % 2, y % 4)]
end



--- Clear (extinguish) a pixel.
-- Coordinates are 0-based; origin (0, 0) is at the top-left.
-- @tparam number x pixel column, 0-based, left to right
-- @tparam number y pixel row, 0-based, top to bottom
function Canvas:unset(x, y)
  local cell_col = math.floor(x / 2) + 1
  local cell_row = math.floor(y / 4) + 1
  local c = self.cells[cell_row][cell_col]
  self.cells[cell_row][cell_col] = UNSET_LUT[c .. string.char(x % 2, y % 4)]
end



--- Render the canvas to a single string with embedded cursor movements.
-- Each row is followed by down+left to reach the start of the next row.
-- After the last row the cursor returns to the top-left of the canvas.
-- @treturn string
function Canvas:render()
  local parts = {}
  local p = 1

  for r = 1, self.rows do
    parts[p] = table.concat(self.cells[r])
    p = p + 1
    parts[p] = self._seq_between
    p = p + 1
  end

  -- cursor is at end of last row; go back to top-left of canvas
  -- overwrite the last _seq_between with the return-to-top-left sequence
  parts[p-1] = self._seq_return

  return table.concat(parts)
end



--- Clear the entire canvas.
-- Fills all cells with the blank state (respects the `invert` option).
function Canvas:clear()
  local cells = self.cells
  local blank = self._blank
  for r = 1, self.rows do
    local row = cells[r]
    for c = 1, self.cols do
      row[c] = blank
    end
  end
end



--- Draw a line between two pixels using Bresenham's algorithm.
-- @tparam number x1 start pixel column, 0-based
-- @tparam number y1 start pixel row, 0-based
-- @tparam number x2 end pixel column, 0-based
-- @tparam number y2 end pixel row, 0-based
-- @tparam[opt=false] boolean clear if truthy, unset pixels instead of setting them
function Canvas:line(x1, y1, x2, y2, clear)
  local op  = clear and self.unset or self.set
  local dx  = math.abs(x2 - x1)
  local dy  = math.abs(y2 - y1)
  local sx  = x1 < x2 and 1 or -1
  local sy  = y1 < y2 and 1 or -1
  local err = dx - dy

  while true do
    op(self, x1, y1)
    if x1 == x2 and y1 == y2 then
      break
    end
    local e2 = 2 * err
    if e2 > -dy then
      err = err - dy
      x1  = x1 + sx
    end
    if e2 < dx then
      err = err + dx
      y1  = y1 + sy
    end
  end
end



--- Draw a circle using the midpoint circle algorithm.
-- @tparam number cx centre pixel column, 0-based
-- @tparam number cy centre pixel row, 0-based
-- @tparam number r  radius in pixels
-- @tparam[opt=false] boolean fill if truthy, fill the interior
-- @tparam[opt=false] boolean clear if truthy, unset pixels instead of setting them
function Canvas:circle(cx, cy, r, fill, clear)
  local op = clear and self.unset or self.set
  local x  = 0
  local y  = r
  local p  = 1 - r

  local function octants(px, py)
    op(self, cx + px, cy + py)
    op(self, cx - px, cy + py)
    op(self, cx + px, cy - py)
    op(self, cx - px, cy - py)
    op(self, cx + py, cy + px)
    op(self, cx - py, cy + px)
    op(self, cx + py, cy - px)
    op(self, cx - py, cy - px)
  end

  octants(x, y)
  while x < y do
    x = x + 1
    if p < 0 then
      p = p + 2 * x + 1
    else
      y = y - 1
      p = p + 2 * (x - y) + 1
    end
    octants(x, y)
  end

  if fill then
    for dy = -r, r do
      local dx = math.floor(math.sqrt(r * r - dy * dy))
      for fx = cx - dx, cx + dx do
        op(self, fx, cy + dy)
      end
    end
  end
end



--- Draw a polygon from an array of `{x, y}` points.
-- 1 point draws a dot, 2 points draw a line, 3+ points draw a closed polygon.
-- With `fill`, the interior is flood-filled using a scanline algorithm.
-- @tparam table points array of `{x, y}` pixel coordinate pairs, 0-based
-- @tparam[opt=false] boolean fill if truthy, fill the interior of the polygon
-- @tparam[opt=false] boolean clear if truthy, unset pixels instead of setting them
function Canvas:polygon(points, fill, clear)
  local op = clear and self.unset or self.set
  local n  = #points

  if n == 0 then
    return
  end

  if n == 1 then
    op(self, points[1][1], points[1][2])
    return
  end

  -- draw edges; for n >= 3 the last edge closes back to points[1]
  local limit = n == 2 and 1 or n
  for i = 1, limit do
    local a = points[i]
    local b = points[(i % n) + 1]
    self:line(a[1], a[2], b[1], b[2], clear)
  end

  if not fill or n < 3 then
    return
  end

  -- scanline fill using the even-odd rule
  local y_min, y_max = points[1][2], points[1][2]
  for i = 2, n do
    local y = points[i][2]
    if y < y_min then y_min = y end
    if y > y_max then y_max = y end
  end

  for y = y_min, y_max do
    local xs = {}
    for i = 1, n do
      local x1, y1 = points[i][1], points[i][2]
      local x2, y2 = points[(i % n) + 1][1], points[(i % n) + 1][2]
      -- count edge only on the lower endpoint to avoid double-counting at vertices
      if (y1 <= y and y < y2) or (y2 <= y and y < y1) then
        xs[#xs + 1] = x1 + (y - y1) * (x2 - x1) / (y2 - y1)
      end
    end
    table.sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = math.floor(xs[i]), math.ceil(xs[i + 1]) do
        op(self, x, y)
      end
    end
  end
end



--- Returns the canvas size in pixels.
-- Return order matches `terminal.size`: width, height.
-- @treturn number pixel width
-- @treturn number pixel height
function Canvas:get_pixels()
  return self.px_h, self.px_w
end



--- Returns the canvas size in display rows and columns.
-- Return order matches `terminal.size`: rows first, then columns.
-- @treturn number rows
-- @treturn number columns
function Canvas:get_size()
  return self.rows, self.cols
end



return Canvas
