--- Module for drawing lines and boxes.
-- Provides functions to create lines and boxes on a terminal screen.
-- @module terminal.draw

local M = {}
package.loaded["terminal.draw"] = M -- Push in `package.loaded` to avoid circular dependencies
M.line = require "terminal.draw.line"

local Sequence = require "terminal.sequence"
local output = require "terminal.output"
local cursor = require "terminal.cursor"
local unpack = unpack or table.unpack
local clear = require "terminal.clear"
local utils = require "terminal.utils"
local text = require "terminal.text"



--- Table with pre-defined box formats.
-- @table box_fmt
-- @field single Single line box format
-- @field double Double line box format
-- @field copy Function to copy a box format, see `box_fmt.copy` for details
M.box_fmt = utils.make_lookup("box-format", {
  single = {
    t = "─",
    b = "─",
    l = "│",
    r = "│",
    tl = "┌",
    tr = "┐",
    bl = "└",
    br = "┘",
    pre = "┤",
    post = "├",
  },
  double = {
    t = "═",
    b = "═",
    l = "║",
    r = "║",
    tl = "╔",
    tr = "╗",
    bl = "╚",
    br = "╝",
    pre = "╡",
    post = "╞",
  },
  --- Copy a box format.
  -- @function box_fmt.copy
  -- @tparam table default the default format to copy
  -- @treturn table a copy of the default format provided
  -- @usage -- create new format with spaces around the title
  -- local fmt = t.box_fmt.copy(t.box_fmt.single)
  -- fmt.pre = fmt.pre .. " "
  -- fmt.post = " " .. fmt.post
  copy = function(default)
    return {
      t = default.t,
      b = default.b,
      l = default.l,
      r = default.r,
      tl = default.tl,
      tr = default.tr,
      bl = default.bl,
      br = default.br,
      pre = default.pre,
      post = default.post,
    }
  end,
})



-- returns a string with all box_fmt characters, to pre-load the character width cache
function M._box_fmt_chars()
  local r = {}
  for _, fmt in pairs(M.box_fmt) do
    if type(fmt) == "table" then
      for _, v in pairs(fmt) do
        if type(v) == "string" then
          r[#r+1] = v
        end
      end
    end
  end
  return table.concat(r)
end



--- Creates a sequence to draw a box, without writing it to the terminal.
-- The box is drawn starting from the top-left corner at the current cursor position,
-- after drawing the cursor will be in the same position.
-- The left, right, top, bottom characters can be empty strings(eg. ""), to not draw them.
-- @tparam number height the height of the box in rows
-- @tparam number width the width of the box in columns
-- @tparam[opt] table format the format for the box (default is single line), with keys:
-- @tparam[opt=" "] string format.t the top horizontal line character
-- @tparam[opt=" "] string format.b the bottom horizontal line character
-- @tparam[opt=""] string format.l the left vertical line character
-- @tparam[opt=""] string format.r the right vertical line character
-- @tparam[opt=""] string format.tl the top left corner character
-- @tparam[opt=""] string format.tr the top right corner character
-- @tparam[opt=""] string format.bl the bottom left corner character
-- @tparam[opt=""] string format.br the bottom right corner character
-- @tparam[opt=""] string format.pre the title-prefix character(s)
-- @tparam[opt=""] string format.post the left-postfix character(s)
-- @tparam[opt=false] bool clear_flag whether to clear the box contents
-- @tparam[opt=""] string title the title to draw
-- @tparam[opt=false] boolean lastcolumn whether to draw the last column of the terminal
-- @tparam[opt="right"] string type the type of title-truncation to apply, either "left", "right", or "drop", see `draw.line.title_fmt` for details
-- @tparam[opt] table title_attr table of attributes for the title, eg. `{ fg = "red", bg = "blue" }`
-- @treturn Sequence The sequence to write to the terminal
-- @within Sequences
function M.box_seq(height, width, format, clear_flag, title, lastcolumn, type, title_attr)
  format = format or M.box_fmt.single
  local vl_w = text.width.utf8swidth(format.l or "")
  local vr_w = text.width.utf8swidth(format.r or "")
  local tl_w = text.width.utf8swidth(format.tl or "")
  local tr_w = text.width.utf8swidth(format.tr or "")
  local bl_w = text.width.utf8swidth(format.bl or "")
  local br_w = text.width.utf8swidth(format.br or "")
  -- get a vertical line, or if empty, just move cursor
  local v_line_l
  if format.l ~= "" then
    v_line_l = M.line.vertical_seq(height - 2, format.l)
  else
    v_line_l = cursor.position.move_seq(height - 3, vl_w)
  end

  -- get a vertical line, or if empty, just move cursor
  local v_line_r
  if format.r ~= "" then
    v_line_r = M.line.vertical_seq(height - 2, format.r, lastcolumn)
  else
    v_line_r = cursor.position.move_seq(height - 3, vr_w)
  end

  -- get a horizontal line, or if empty, just move cursor
  local h_line_t
  if format.t ~= "" then
    h_line_t = M.line.title_seq(width - tl_w - tr_w, title, format.t or " ",
                format.pre or "", format.post or "", type, title_attr)
  else
    h_line_t = cursor.position.move_seq(0, width - tl_w - tr_w)
  end

  -- get a horizontal line, or if empty, just move cursor
  local h_line_b
  if format.b ~= "" then
    h_line_b = M.line.horizontal_seq(width - bl_w - br_w, format.b)
  else
    h_line_b = cursor.position.move_seq(0, width - bl_w - br_w)
  end

  lastcolumn = lastcolumn and 1 or 0

  local r = {
    -- draw top
    format.tl or "",
    h_line_t,
    format.tr or "",
    -- position to draw right, and draw it
    cursor.position.move_seq(1, -vr_w + lastcolumn),
    v_line_r,
    -- position back to top left, and draw left
    cursor.position.move_seq(-height + 3, -width + lastcolumn),
    v_line_l,
    -- draw bottom
    cursor.position.move_seq(1, -vl_w),
    format.bl or "",
    h_line_b,
    format.br or "",
    -- return to top left
    cursor.position.move_seq(-height + 1, -width + lastcolumn),
  }
  if clear_flag then
    local l = #r
    r[l+1] = cursor.position.move_seq(1, vl_w)
    r[l+2] = clear.box_seq(height - 2, width - vl_w - vr_w)
    r[l+3] = cursor.position.move_seq(-1, -vl_w)
  end
  return Sequence(unpack(r))
end



--- Draws a box and writes it to the terminal.
-- @tparam number height the height of the box in rows
-- @tparam number width the width of the box in columns
-- @tparam table format the format for the box, see `box_seq` for details.
-- @tparam bool clear_flag whether to clear the box contents
-- @tparam[opt=""] string title the title to draw
-- @tparam[opt=false] boolean lastcolumn whether to draw the last column of the terminal
-- @tparam[opt="right"] string type the type of title-truncation to apply, either "left", "right", or "drop", see `draw.line.title_fmt` for details
-- @tparam[opt] table title_attr table of attributes for the title, eg. `{ fg = "red", bg = "blue" }`
-- @return true
function M.box(height, width, format, clear_flag, title, lastcolumn, type, title_attr)
  output.write(M.box_seq(height, width, format, clear_flag, title, lastcolumn, type, title_attr))
  return true
end



return M
