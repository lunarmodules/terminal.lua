--- A canvas using Unicode Braille characters for TUI pixel graphics.
-- Each cell is 2 pixels wide, 4 pixels tall (8 dots per braille character).
-- Cells store full UTF-8 braille characters, so rendering is a bare table.concat.
-- Draw path is a single flat table lookup keyed by current_char .. col_byte .. row_byte.

local M = {}



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
      SET_LUT[key]   = braille(i | bit)
      UNSET_LUT[key] = braille(i & ~bit)
    end
  end
end



local BLANK = braille(0)  -- U+2800, empty braille cell



local Canvas = {}
Canvas.__index = Canvas



--- Create a new canvas.
-- @param px_w  Width in pixels
-- @param px_h  Height in pixels
function M.new(px_w, px_h)
  if px_w <= 0 or px_h <= 0 then
    error("canvas dimensions must be positive")
  end

  local cols = math.ceil(px_w / 2)
  local rows = math.ceil(px_h / 4)

  local cells = {}
  for r = 1, rows do
    local row = {}
    for c = 1, cols do
      row[c] = BLANK
    end
    cells[r] = row
  end

  return setmetatable({
    px_w  = px_w,
    px_h  = px_h,
    cols  = cols,
    rows  = rows,
    cells = cells,
  }, Canvas)
end



--- Set (illuminate) a pixel.
-- @param x  0-based pixel column (0 = left)
-- @param y  0-based pixel row   (0 = top)
function Canvas:set(x, y)
  local cell_col = math.floor(x / 2) + 1
  local cell_row = math.floor(y / 4) + 1
  local c = self.cells[cell_row][cell_col]
  self.cells[cell_row][cell_col] = SET_LUT[c .. string.char(x % 2, y % 4)]
end



--- Clear (extinguish) a pixel.
-- @param x  0-based pixel column (0 = left)
-- @param y  0-based pixel row   (0 = top)
function Canvas:unset(x, y)
  local cell_col = math.floor(x / 2) + 1
  local cell_row = math.floor(y / 4) + 1
  local c = self.cells[cell_row][cell_col]
  self.cells[cell_row][cell_col] = UNSET_LUT[c .. string.char(x % 2, y % 4)]
end



--- Render the canvas to a list of UTF-8 strings, one per cell-row.
-- @return table of strings (1-based, top to bottom)
function Canvas:render()
  local lines = {}
  for r = 1, self.rows do
    lines[r] = table.concat(self.cells[r])
  end
  return lines
end



--- Clear the entire canvas.
function Canvas:clear()
  local cells = self.cells
  for r = 1, self.rows do
    local row = cells[r]
    for c = 1, self.cols do
      row[c] = BLANK
    end
  end
end



return M
