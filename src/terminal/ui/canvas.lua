--- A canvas using Unicode Braille characters for TUI pixel graphics.
-- Each cell is 2 pixels wide, 4 pixels tall (8 dots per braille character).
--
-- Pixel coordinates are 0-based. The origin (0, 0) is at the top-left corner,
-- with x increasing to the right and y increasing downward.
--
-- Example usage:
--     local Canvas = require "terminal.ui.canvas"
--     local c = Canvas({ width = 60, height = 30 })
--     c:set(10, 5)  -- set a pixel at (10, 5)
--     print(c:render({ print = true }))  -- render the canvas for printing
-- @classmod ui.Canvas

local position = require "terminal.cursor.position"
local concat = table.concat
local utils = require "terminal.utils"
local floor = math.floor
local char = string.char
local sort = table.sort
local sqrt = math.sqrt
local ceil = math.ceil
local sys = require "system"
local abs = math.abs



-- Dot bit positions within a braille cell:
--   col 0 (left):  row 0=1, row 1=2, row 2=4, row 3=64
--   col 1 (right): row 0=8, row 1=16, row 2=32, row 3=128
-- Row 0 is the TOP pixel in the cell.
local DOT_BIT = {
  [0] = { [0] = 1, [1] = 2,  [2] = 4,  [3] = 64 },
  [1] = { [0] = 8, [1] = 16, [2] = 32, [3] = 128 },
}



-- Encode a braille dot-pattern index (0–255) as a UTF-8 string.
-- U+2800+i: byte1=226, byte2=160+(i//64), byte3=128+(i%64)
local function braille(i)
  return char(226, 160 + floor(i / 64), 128 + (i % 64))
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
  local fi = sys.bitflag(i)
  for col = 0, 1 do
    for row = 0, 3 do
      local fb = sys.bitflag(DOT_BIT[col][row])
      local key = ch .. char(col, row)
      SET_LUT[key]   = braille((fi + fb):value())
      UNSET_LUT[key] = braille((fi - fb):value())
    end
  end
end



local BLANK   = braille(0)    -- U+2800, all dots off
local FILLED  = braille(255)  -- U+28FF, all dots on



local Canvas = utils.class()



--- Create a new canvas.
-- Do not call this method directly, call on the class instead.
-- @tparam table opts
-- @tparam number opts.width   Width in display columns (each column is 2 pixels wide)
-- @tparam number opts.height  Height in display rows (each row is 4 pixels tall)
-- @tparam[opt=false] boolean opts.invert  If true, cleared cells are fully lit instead of empty
-- @usage
-- local Canvas = require "terminal.ui.canvas"
-- local c = Canvas({ width = 60, height = 30 })  -- call on the class to invoke the constructor
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
-- Out-of-bounds coordinates are ignored (no error).
-- @tparam number x pixel column, 0-based, left to right
-- @tparam number y pixel row, 0-based, top to bottom
function Canvas:set(x, y)
  if x < 0 or x >= self.px_w or
     y < 0 or y >= self.px_h then
    return
  end

  local cell_col = floor(x / 2) + 1
  local cell_row = floor(y / 4) + 1
  local c = self.cells[cell_row][cell_col]
  self.cells[cell_row][cell_col] = SET_LUT[c .. char(x % 2, y % 4)]
end



--- Clear (extinguish) a pixel.
-- Coordinates are 0-based; origin (0, 0) is at the top-left.
-- Out-of-bounds coordinates are ignored (no error).
-- @tparam number x pixel column, 0-based, left to right
-- @tparam number y pixel row, 0-based, top to bottom
function Canvas:unset(x, y)
  if x < 0 or x >= self.px_w or
     y < 0 or y >= self.px_h then
    return
  end

  local cell_col = floor(x / 2) + 1
  local cell_row = floor(y / 4) + 1
  local c = self.cells[cell_row][cell_col]
  self.cells[cell_row][cell_col] = UNSET_LUT[c .. char(x % 2, y % 4)]
end



--- Render the canvas to a single string.
-- Without `opts.print`: each row is followed by cursor down+left, and after the last
-- row the cursor returns to the top-left of the rendered area.
-- With `opts.print`: rows are separated by newlines with no cursor movement sequences
-- and no trailing newline; suitable for plain `io.write` / `print` output.
-- @tparam[opt={}] table opts
-- @tparam[opt=false] boolean opts.print if truthy, use newline separators with no return sequence
-- @tparam[opt=1] number opts.row  first cell row of the viewport (1-based)
-- @tparam[opt=1] number opts.col  first cell column of the viewport (1-based)
-- @tparam[opt=self.rows] number opts.rows  number of rows to render
-- @tparam[opt=self.cols] number opts.cols  number of columns to render
-- @treturn string
function Canvas:render(opts)
  opts = opts or {}
  local r1    = opts.row  or 1
  local c1    = opts.col  or 1
  local vrows = opts.rows or self.rows
  local vcols = opts.cols or self.cols
  local r2 = r1 + vrows - 1
  local c2 = c1 + vcols - 1
  if r1 < 1 or c1 < 1 or
     r2 > self.rows or c2 > self.cols or
     r1 > r2 or c1 > c2 then
    error("viewport out of bounds", 2)
  end

  local seq_between, seq_return
  if opts.print then
    seq_between = "\n"
    seq_return  = ""
  else
    seq_between = position.down_seq(1) .. position.left_seq(vcols)
    seq_return  = position.left_seq(vcols) .. position.up_seq(vrows - 1)
  end

  local parts = {}
  local p = 1
  for r = r1, r2 do
    parts[p] = concat(self.cells[r], "", c1, c2)
    p = p + 1
    parts[p] = seq_between
    p = p + 1
  end
  -- overwrite the last seq_between with the 'return' sequence
  parts[p-1] = seq_return

  return concat(parts)
end



--- Return a deep copy of this canvas with identical dimensions and pixel state.
-- @treturn Canvas Copy of the canvas
function Canvas:clone()
  local c = Canvas({ width = self.cols, height = self.rows })
  for k, v in pairs(self) do
    c[k] = v
  end
  c.cells = {}

  for r = 1, self.rows do
    local src = self.cells[r]
    local dst = {}
    for col = 1, self.cols do
      dst[col] = src[col]
    end
    c.cells[r] = dst
  end

  return c
end



--- Clear the entire canvas.
-- Fills all cells with the blank state (respects the `invert` option passed upon instantiation).
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



--- Draw a line between two pixels.
-- @tparam table opts
-- @tparam number opts.x1 start pixel column, 0-based
-- @tparam number opts.y1 start pixel row, 0-based
-- @tparam number opts.x2 end pixel column, 0-based
-- @tparam number opts.y2 end pixel row, 0-based
-- @tparam[opt=false] boolean opts.erase if truthy, unset pixels instead of setting them
function Canvas:line(opts)
  local x1 = opts.x1
  local y1 = opts.y1
  local x2 = opts.x2
  local y2 = opts.y2
  local op = opts.erase and self.unset or self.set
  local dx = abs(x2 - x1)
  local dy = abs(y2 - y1)
  local sx = x1 < x2 and 1 or -1
  local sy = y1 < y2 and 1 or -1
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
-- @tparam table opts
-- @tparam number opts.x centre pixel column, 0-based
-- @tparam number opts.y centre pixel row, 0-based
-- @tparam number opts.r radius in pixels
-- @tparam[opt=false] boolean opts.fill if truthy, fill the interior
-- @tparam[opt=false] boolean opts.erase if truthy, unset pixels instead of setting them
function Canvas:circle(opts)
  local cx = opts.x
  local cy = opts.y
  local r = opts.r
  local fill = opts.fill
  local erase = opts.erase
  local op = erase and self.unset or self.set
  local x = 0
  local y = r
  local p = 1 - r

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
      local dx = floor(sqrt(r * r - dy * dy))
      for fx = cx - dx, cx + dx do
        op(self, fx, cy + dy)
      end
    end
  end
end



--- Draw a polygon from an array of `{x, y}` points.
-- 1 point draws a dot, 2 points draw a line, 3+ points draw a closed polygon by default.
-- @tparam table opts
-- @tparam table opts.points array of `{x, y}` pixel coordinate pairs, 0-based
-- @tparam[opt=false] boolean opts.open if truthy, do not close the path back to the first point
-- @tparam[opt=false] boolean opts.fill if truthy, fill the interior of the polygon
-- @tparam[opt=false] boolean opts.erase if truthy, unset pixels instead of setting them
function Canvas:polygon(opts)
  local points = opts.points
  local erase = opts.erase
  local open = opts.open
  local fill = opts.fill
  local op = erase and self.unset or self.set
  local n = #points

  if open and fill then
    error("fill requires a closed path (open and fill cannot both be true)", 2)
  end

  if n == 0 then
    return
  end

  if n == 1 then
    op(self, points[1][1], points[1][2])
    return
  end

  -- draw edges; closed path connects last point back to first
  local limit = (open or n == 2) and n - 1 or n
  for i = 1, limit do
    local a = points[i]
    local b = points[(i % n) + 1]
    self:line({ x1 = a[1], y1 = a[2], x2 = b[1], y2 = b[2], erase = erase })
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
    sort(xs)
    for i = 1, #xs - 1, 2 do
      for x = floor(xs[i]), ceil(xs[i + 1]) do
        op(self, x, y)
      end
    end
  end
end



--- Returns the canvas size in pixels.
-- @treturn number pixel height
-- @treturn number pixel width
function Canvas:get_pixels()
  return self.px_h, self.px_w
end



--- Returns the canvas size in display rows and columns.
-- @treturn number rows
-- @treturn number columns
function Canvas:get_size()
  return self.rows, self.cols
end



return Canvas
