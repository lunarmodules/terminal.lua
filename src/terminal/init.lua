--- Terminal library for Lua.
--
-- This terminal library builds upon the cross-platform terminal capabilities of LuaSystem. As such
-- it works modern terminals on Windows, Unix, and Mac systems.
--
-- It provides a simple and consistent interface to the terminal, allowing for cursor positioning,
-- cursor shape and visibility, text formatting, and more.
--
-- For generic instruction please read the [introduction](topics/01-introduction.md.html).
--
-- @copyright Copyright (c) 2024-2024 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE.md`.

local M = {
  _VERSION = "0.0.1",
  _COPYRIGHT = "Copyright (c) 2024-2024 Thijs Schreijer",
  _DESCRIPTION = "Cross platform terminal library for Lua (Windows/Unix/Mac)",
}

--- Returns the height and width of the terminal screen.
-- @treturn number, number the height in rows and the width in columns
function M.get_dimensions()
  local size = sys.get_terminal_size()
  return size.height, size.width
end

--- Sets the cursor position and writes it to the terminal, without pushing onto the stack.
-- @tparam number row
-- @tparam number column
-- @return true
-- @within cursor_position
function M.cursor_set(row, column)
  -- Retrieve terminal dimensions
  local height, width = M.get_dimensions()

  -- Resolve negative indices using utils.resolve_index
  row = utils.resolve_index(row, height)
  column = utils.resolve_index(column, width)

  -- Rest of the cursor_set logic
  output.write("\27[" .. tostring(row) .. ";" .. tostring(column) .. "H")
  return true
end

local pack, unpack do
  -- nil-safe versions of pack/unpack
  local oldunpack = _G.unpack or table.unpack -- luacheck: ignore
  pack = function(...) return { n = select("#", ...), ... } end
  unpack = function(t, i, j) return oldunpack(t, i or 1, j or t.n or #t) end
end

local sys = require "system"
local utils = require "terminal.utils"

-- Push the module table already in `package.loaded` to avoid circular dependencies
package.loaded["terminal"] = M
-- load the submodules
M.input = require("terminal.input")
M.output = require("terminal.output")
M.clear = require("terminal.clear")
M.scroll = require("terminal.scroll")
-- create locals
local output = M.output
local input = M.input
local clear = M.clear
local scroll = M.scroll

local t -- the terminal/stream to operate on, default io.stderr
local bsleep  -- a blocking sleep function
local asleep   -- a (optionally) non-blocking sleep function

--=============================================================================
-- cursor shapes
--=============================================================================

--- Cursor shapes and visibility.
-- Managing the shape and visibility of the cursor. These functions just generate
-- required ansi sequences, without any stack operations.
-- @section cursor_shapes

local cursor_hide = "\27[?25l"
local cursor_show = "\27[?25h"

--- Returns the ansi sequence to show/hide the cursor without writing it to the terminal.
-- @tparam boolean visible true to show, false to hide
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_shapes
function M.visibles(visible)
  return visible and cursor_show or cursor_hide
end

--- Shows or hides the cursor and writes it to the terminal.
-- @tparam boolean visible true to show, false to hide
-- @return true
-- @within cursor_shapes
function M.visible(visible)
  output.write(M.visibles(visible))
  return true
end

local shape_reset = "\27[0 q"

local shapes = utils.make_lookup("cursor shape", {
  block_blink     = "\27[1 q",
  block           = "\27[2 q",
  underline_blink = "\27[3 q",
  underline       = "\27[4 q",
  bar_blink       = "\27[5 q",
  bar             = "\27[6 q",
})

--- Returns the ansi sequence for a cursor shape without writing it to the terminal.
-- @tparam string shape the shape to get, one of the keys `"block"`,
-- `"block_blink"`, `"underline"`, `"underline_blink"`, `"bar"`, `"bar_blink"`
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_shapes
function M.shapes(shape)
  return shapes[shape]
end

--- Sets the cursor shape and writes it to the terminal.
-- @tparam string shape the shape to set, one of the keys `"block"`,
-- `"block_blink"`, `"underline"`, `"underline_blink"`, `"bar"`, `"bar_blink"`
-- @return true
-- @within cursor_shapes
function M.shape(shape)
  output.write(shapes[shape])
  return true
end

--=============================================================================
--- Cursor shape stack.
-- Managing the shape and visibility of the cursor based on a stack. Since the
-- current shape cannot be requested, using stacks allows the user to revert to
-- a previous state since the stacks keeps track of that.
-- It does however require the user to use balanced operations; `push`/`pop`.
-- @section cursor_shape_stack

local _visible_stack = {
  true
}

--- Returns the ansi sequence to show/hide the cursor at the top of the stack without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_shape_stack
function M.visible_applys()
  return M.visibles(_visible_stack[#_visible_stack])
end

--- Returns the ansi sequence to show/hide the cursor at the top of the stack, and writes it to the terminal.
-- @return true
-- @within cursor_shape_stack
function M.visible_apply()
  output.write(M.visible_applys())
  return true
end

--- Pushes a cursor visibility onto the stack (and returns it), without writing it to the terminal.
-- @tparam boolean visible true to show, false to hide
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_shape_stack
function M.visible_pushs(visible)
  _visible_stack[#_visible_stack + 1] = not not visible
  return M.visible_applys()
end

--- Pushes a cursor visibility onto the stack, and writes it to the terminal.
-- @tparam boolean visible true to show, false to hide
-- @return true
-- @within cursor_shape_stack
function M.visible_push(visible)
  output.write(M.visible_pushs(visible))
  return true
end

--- Pops `n` cursor visibility(ies) off the stack (and returns the last one), without writing it to the terminal.
-- @tparam[opt=1] number n number of visibilities to pop
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_shape_stack
function M.visible_pops(n)
  local new_last = math.max(#_visible_stack - (n or 1), 1)
  for i = new_last + 1, #_visible_stack do
    _visible_stack[i] = nil
  end
  return M.visible_applys()
end

--- Pops `n` cursor visibility(ies) off the stack, and writes the last one to the terminal.
-- @tparam[opt=1] number n number of visibilities to pop
-- @return true
-- @within cursor_shape_stack
function M.visible_pop(n)
  output.write(M.visible_pops(n))
  return true
end

local _shapestack = {
  shape_reset
}

--- Re-applies the shape at the top of the stack (returns it, does not write it to the terminal).
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_shape_stack
function M.shape_applys()
  return _shapestack[#_shapestack]
end

--- Re-applies the shape at the top of the stack, and writes it to the terminal.
-- @return true
-- @within cursor_shape_stack
function M.shape_apply()
  output.write(_shapestack[#_shapestack])
  return true
end

--- Pushes a cursor shape onto the stack (and returns it), without writing it to the terminal.
-- @tparam string shape the shape to push, one of the keys `"block"`,
-- `"block_blink"`, `"underline"`, `"underline_blink"`, `"bar"`, `"bar_blink"`
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_shape_stack
function M.shape_pushs(shape)
  _shapestack[#_shapestack + 1] = shapes[shape]
  return M.shape_applys()
end

--- Pushes a cursor shape onto the stack, and writes it to the terminal.
-- @tparam string shape the shape to push, one of the keys `"block"`,
-- `"block_blink"`, `"underline"`, `"underline_blink"`, `"bar"`, `"bar_blink"`
-- @return true
-- @within cursor_shape_stack
function M.shape_push(shape)
  output.write(M.shape_pushs(shape))
  return true
end

--- Pops `n` cursor shape(s) off the stack (and returns the last one), without writing it to the terminal.
-- @tparam[opt=1] number n number of shapes to pop
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_shape_stack
function M.shape_pops(n)
  local new_last = math.max(#_shapestack - (n or 1), 1)
  for i = new_last + 1, #_shapestack do
    _shapestack[i] = nil
  end
  return M.shape_applys()
end

--- Pops `n` cursor shape(s) off the stack, and writes the last one to the terminal.
-- @tparam[opt=1] number n number of shapes to pop
-- @return true
-- @within cursor_shape_stack
function M.shape_pop(n)
  output.write(M.shape_pops(n))
  return true
end

--=============================================================================
-- cursor position
--=============================================================================
--- Cursor positioning.
-- Managing the cursor in absolute positions, without stack operations.
-- @section cursor_position

local _positionstack = {}

--- returns the sequence for requesting cursor position as a string
function M.cursor_get_querys()
  return "\27[6n"
end

--- write the sequence for requesting cursor position, without flushing
function M.cursor_get_query()
  output.write(M.cursor_get_querys())
end

--- Requests the current cursor position from the terminal.
-- Will read entire keyboard buffer to empty it, then request the cursor position.
-- The output buffer will be flushed.
-- In case of a keyboard error, the error will be returned here, but also by
-- `readansi` on a later call, because readansi retains the proper order of keyboard
-- input, whilst this function buffers input.
-- @treturn[1] number row
-- @treturn[1] number column
-- @treturn[2] nil
-- @treturn[2] string error message in case of a keyboard read error
-- @within cursor_position
function M.cursor_get()
  -- first empty keyboard buffer
  local ok, err = input.preread()
  if not ok then
    return nil, err
  end

  -- request cursor position
  M.cursor_get_query()
  t:flush()

  -- get position
  local r, err = input.read_cursor_pos(1)
  if not r then
    return nil, err
  end
  return unpack(r[1])
end

--- Returns the ansi sequence to store to backup the current sursor position (in terminal storage, not stacked).
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_position
function M.cursor_saves()
  return "\27[s"
end

--- Writes the ansi sequence to store the current cursor position (in terminal storage, not stacked) to the terminal.
-- @return true
-- @within cursor_position
function M.cursor_save()
  output.write(M.cursor_saves())
  return true
end

--- Returns the ansi sequence to restore the cursor position (from the terminal storage, not stacked).
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_position
function M.cursor_restores()
  return "\27[u"
end

--- Writes the ansi sequence to restore the cursor position (from the terminal storage, not stacked) to the terminal.
-- @return true
-- @within cursor_position
function M.cursor_restore()
  output.write(M.cursor_restores())
  return true
end

--- Creates ansi sequence to set the cursor position without writing to the terminal or pushing onto the stack.
-- @tparam number row
-- @tparam number column
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_position
function M.cursor_sets(row, column)
 -- Retrieve terminal dimensions once
local size = sys.get_terminal_size()
row = utils.resolve_index(row, size.height)
column = utils.resolve_index(column, size.width)
  return "\27[" .. tostring(row) .. ";" .. tostring(column) .. "H"
end

--- Sets the cursor position and writes it to the terminal, without pushing onto the stack.
-- @tparam number row
-- @tparam number column
-- @return true
-- @within cursor_position
function M.cursor_set(row, column)
  -- Retrieve terminal dimensions once
  local size = sys.get_terminal_size()
  row = utils.resolve_index(row, size.height)
  column = utils.resolve_index(column, size.width)

  -- Write the cursor position to the terminal
  output.write("\27[" .. tostring(row) .. ";" .. tostring(column) .. "H")
  return true
end

--=============================================================================
--- Cursor positioning stack based.
-- Managing the cursor in absolute positions, stack based.
-- @section cursor_position_stack

--- Pushes the current cursor position onto the stack, and returns an ansi sequence to move to the new position without writing it to the terminal.
-- Calls cursor.get() under the hood.
-- @tparam number row
-- @tparam number column
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_position_stack
function M.cursor_pushs(row, column)
  local r, c = M.cursor_get()
  -- ignore the error, since we need to keep the stack in sync for pop/push operations
  _positionstack[#_positionstack + 1] = { r, c }
  return M.cursor_sets(row, column)
end

--- Pushes the current cursor position onto the stack, and writes an ansi sequence to move to the new position to the terminal.
-- Calls cursor.get() under the hood.
-- @tparam number row
-- @tparam number column
-- @return true
-- @within cursor_position_stack
function M.cursor_push(row, column)
  output.write(M.cursor_pushs(row, column))
  return true
end

--- Pops the last n cursor positions off the stack, and returns an ansi sequence to move to the last one without writing it to the terminal.
-- @tparam[opt=1] number n number of positions to pop
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_position_stack
function M.cursor_pops(n)
  n = n or 1
  local entry
  while n > 0 do
    entry = table.remove(_positionstack)
    n = n - 1
  end
  if not entry then
    return ""
  end
  return M.cursor_sets(entry[1], entry[2])
end

--- Pops the last n cursor position off the stack, and writes an ansi sequence to move to the last one to the terminal.
-- @tparam[opt=1] number n number of positions to pop
-- @return true
-- @within cursor_position_stack
function M.cursor_pop(n)
  output.write(M.cursor_pops(n))
  return true
end

--=============================================================================
-- cursor movements
--=============================================================================
--- Cursor movements.
-- Moving the cursor around, without stack interactions.
-- @section cursor_moving

--- Creates an ansi sequence to move the cursor up without writing it to the terminal.
-- @tparam[opt=1] number n number of lines to move up
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_ups(n)
  n = n or 1
  return "\27["..tostring(n).."A"
end

--- Moves the cursor up and writes it to the terminal.
-- @tparam[opt=1] number n number of lines to move up
-- @return true
-- @within cursor_moving
function M.cursor_up(n)
  output.write(M.cursor_ups(n))
  return true
end

--- Creates an ansi sequence to move the cursor down without writing it to the terminal.
-- @tparam[opt=1] number n number of lines to move down
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_downs(n)
  n = n or 1
  return "\27["..tostring(n).."B"
end

--- Moves the cursor down and writes it to the terminal.
-- @tparam[opt=1] number n number of lines to move down
-- @return true
-- @within cursor_moving
function M.cursor_down(n)
  output.write(M.cursor_downs(n))
  return true
end

--- Creates an ansi sequence to move the cursor vertically without writing it to the terminal.
-- @tparam[opt=1] number n number of lines to move (negative for up, positive for down)
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_verticals(n)
  n = n or 1
  if n == 0 then
    return ""
  end
  return "\27[" .. (n < 0 and (tostring(-n) .. "A") or (tostring(n) .. "B"))
end

--- Moves the cursor vertically and writes it to the terminal.
-- @tparam[opt=1] number n number of lines to move (negative for up, positive for down)
-- @return true
-- @within cursor_moving
function M.cursor_vertical(n)
  output.write(M.cursor_verticals(n))
  return true
end

--- Creates an ansi sequence to move the cursor left without writing it to the terminal.
-- @tparam[opt=1] number n number of columns to move left
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_lefts(n)
  n = n or 1
  return "\27["..tostring(n).."D"
end

--- Moves the cursor left and writes it to the terminal.
-- @tparam[opt=1] number n number of columns to move left
-- @return true
-- @within cursor_moving
function M.cursor_left(n)
  output.write(M.cursor_lefts(n))
  return true
end

--- Creates an ansi sequence to move the cursor right without writing it to the terminal.
-- @tparam[opt=1] number n number of columns to move right
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_rights(n)
  n = n or 1
  return "\27["..tostring(n).."C"
end

--- Moves the cursor right and writes it to the terminal.
-- @tparam[opt=1] number n number of columns to move right
-- @return true
-- @within cursor_moving
function M.cursor_right(n)
  output.write(M.cursor_rights(n))
  return true
end

--- Creates an ansi sequence to move the cursor horizontally without writing it to the terminal.
-- @tparam[opt=1] number n number of columns to move (negative for left, positive for right)
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_horizontals(n)
  n = n or 1
  if n == 0 then
    return ""
  end
  return "\27[" .. (n < 0 and (tostring(-n) .. "D") or (tostring(n) .. "C"))
end

--- Moves the cursor horizontally and writes it to the terminal.
-- @tparam[opt=1] number n number of columns to move (negative for left, positive for right)
-- @return true
-- @within cursor_moving
function M.cursor_horizontal(n)
  output.write(M.cursor_horizontals(n))
  return true
end

--- Creates an ansi sequence to move the cursor horizontal and vertical without writing it to the terminal.
-- @tparam[opt=0] number rows number of rows to move (negative for up, positive for down)
-- @tparam[opt=0] number columns number of columns to move (negative for left, positive for right)
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_moves(rows, columns)
  return M.cursor_verticals(rows or 0) .. M.cursor_horizontals(columns or 0)
end

--- Moves the cursor horizontal and vertical and writes it to the terminal.
-- @tparam[opt=0] number rows number of rows to move (negative for up, positive for down)
-- @tparam[opt=0] number columns number of columns to move (negative for left, positive for right)
-- @return true
-- @within cursor_moving
function M.cursor_move(rows, columns)
  output.write(M.cursor_moves(rows, columns))
  return true
end

--- Creates an ansi sequence to move the cursor to a column on the current row without writing it to the terminal.
-- @tparam number column the column to move to
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_tocolumns(column)
  return "\27["..tostring(column).."G"
end

--- Moves the cursor to a column on the current row and writes it to the terminal.
-- @tparam number column the column to move to
-- @return true
-- @within cursor_moving
function M.cursor_tocolumn(column)
  t:write(M.cursor_tocolumns(column))
  return true
end

--- Creates an ansi sequence to move the cursor to a row on the current column without writing it to the terminal.
-- @tparam number row the row to move to
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_torows(row)
  return "\27["..tostring(row).."d"
end

--- Moves the cursor to a row on the current column and writes it to the terminal.
-- @tparam number row the row to move to
-- @return true
-- @within cursor_moving
function M.cursor_torow(row)
  t:write(M.cursor_torows(row))
  return true
end

--- Creates an ansi sequence to move the cursor to the start of the next row without writing it to the terminal.
-- @tparam[opt=1] number rows the number of rows to move down
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_row_downs(rows)
  return "\27["..tostring(rows or 1).."E"
end

--- Moves the cursor to the start of the next row and writes it to the terminal.
-- @tparam[opt=1] number rows the number of rows to move down
-- @return true
-- @within cursor_moving
function M.cursor_row_down(rows)
  t:write(M.cursor_row_downs(rows))
  return true
end

--- Creates an ansi sequence to move the cursor to the start of the previous row without writing it to the terminal.
-- @tparam[opt=1] number rows the number of rows to move up
-- @treturn string ansi sequence to write to the terminal
-- @within cursor_moving
function M.cursor_row_ups(rows)
  return "\27["..tostring(rows or 1).."F"
end

--- Moves the cursor to the start of the previous row and writes it to the terminal.
-- @tparam[opt=1] number rows the number of rows to move up
-- @return true
-- @within cursor_moving
function M.cursor_row_up(rows)
  t:write(M.cursor_row_ups(rows))
  return true
end

--=============================================================================
-- text: colors & attributes
--=============================================================================
-- Text colors and attributes.
-- Managing the text color and attributes.
-- @section textcolor

local fg_color_reset = "\27[39m"
local bg_color_reset = "\27[49m"
local attribute_reset = "\27[0m"
local underline_on = "\27[4m"
local underline_off = "\27[24m"
local blink_on = "\27[5m"
local blink_off = "\27[25m"
local reverse_on = "\27[7m"
local reverse_off = "\27[27m"

local fg_base_colors = utils.make_lookup("foreground color string", {
  black = "\27[30m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  magenta = "\27[35m",
  cyan = "\27[36m",
  white = "\27[37m",
})

local bg_base_colors = utils.make_lookup("background color string",{
  black = "\27[40m",
  red = "\27[41m",
  green = "\27[42m",
  yellow = "\27[43m",
  blue = "\27[44m",
  magenta = "\27[45m",
  cyan = "\27[46m",
  white = "\27[47m",
})

local default_colors = {
  fg = fg_color_reset, -- reset fg
  bg = bg_color_reset, -- reset bg
  brightness = 2, -- normal
  underline = false,
  blink = false,
  reverse = false,
  ansi = fg_color_reset .. bg_color_reset .. attribute_reset,
}

local _colorstack = {
  default_colors,
}

-- Takes a color name/scheme by user and returns the ansi sequence for it.
-- This function takes three color types:
--
-- 1. base colors: black, red, green, yellow, blue, magenta, cyan, white. Use as `color("red")`.
-- 2. extended colors: a number between 0 and 255. Use as `color(123)`.
-- 3. RGB colors: three numbers between 0 and 255. Use as `color(123, 123, 123)`.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @tparam[opt] boolean fg true for foreground, false for background
-- @treturn string ansi sequence to write to the terminal
local function colorcode(r, g, b, fg)
  if type(r) == "string" then
    return fg and fg_base_colors[r] or bg_base_colors[r]
  end

  if type(r) ~= "number" or g < 0 or g > 255 then
    return "expected arg #1 to be a string or an integer 0-255, got " .. tostring(r) .. " (" .. type(r) .. ")"
  end
  if g == nil then
    return fg and "\27[38;5;" .. tostring(math.floor(r)) .. "m" or "\27[48;5;" .. tostring(math.floor(r)) .. "m"
  end

  if type(g) ~= "number" or g < 0 or g > 255 then
    return "expected arg #2 to be a number 0-255, got " .. tostring(g) .. " (" .. type(g) .. ")"
  end
  g = tostring(math.floor(g))

  if type(b) ~= "number" or b < 0 or b > 255 then
    return "expected arg #3 to be a number 0-255, got " .. tostring(g) .. " (" .. type(g) .. ")"
  end
  b = tostring(math.floor(b))

  return fg and "\27[38;2;" .. r .. ";" .. g .. ";" .. b .. "m" or "\27[48;2;" .. r .. ";" .. g .. ";" .. b .. "m"
end

--- Creates an ansi sequence to set the foreground color without writing it to the terminal.
-- This function takes three color types:
--
-- 1. base colors: black, red, green, yellow, blue, magenta, cyan, white. Use as `color_fgs("red")`.
-- 2. extended colors: a number between 0 and 255. Use as `color_fgs(123)`.
-- 3. RGB colors: three numbers between 0 and 255. Use as `color_fgs(123, 123, 123)`.
--
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.color_fgs(r, g, b)
  return colorcode(r, g, b, true)
end

--- Sets the foreground color and writes it to the terminal.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @return true
-- @within textcolor
function M.color_fg(r, g, b)
  output.write(M.color_fgs(r, g, b))
  return true
end

--- Creates an ansi sequence to set the background color without writing it to the terminal.
-- This function takes three color types:
--
-- 1. base colors: black, red, green, yellow, blue, magenta, cyan, white. Use as `color_bgs("red")`.
-- 2. extended colors: a number between 0 and 255. Use as `color_bgs(123)`.
-- 3. RGB colors: three numbers between 0 and 255. Use as `color_bgs(123, 123, 123)`.
--
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.color_bgs(r, g, b)
  return colorcode(r, g, b, false)
end

--- Sets the background color and writes it to the terminal.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @return true
-- @within textcolor
function M.color_bg(r, g, b)
  output.write(M.color_bgs(r, g, b))
  return true
end

--- Creates an ansi sequence to set the underline attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.underline_ons()
  return underline_on
end

--- Sets the underline attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.underline_on()
  output.write(M.underline_ons())
  return true
end

--- Creates an ansi sequence to unset the underline attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.underline_offs()
  return underline_off
end

--- Unsets the underline attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.underline_off()
  output.write(M.underline_offs())
  return true
end

--- Creates an ansi sequence to set the blink attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.blink_ons()
  return blink_on
end

--- Sets the blink attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.blink_on()
  output.write(M.blink_ons())
  return true
end

--- Creates an ansi sequence to unset the blink attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.blink_offs()
  return blink_off
end

--- Unsets the blink attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.blink_off()
  output.write(M.blink_offs())
  return true
end

--- Creates an ansi sequence to set the reverse attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.reverse_ons()
  return reverse_on
end

--- Sets the reverse attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.reverse_on()
  output.write(M.reverse_ons())
  return true
end

--- Creates an ansi sequence to unset the reverse attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.reverse_offs()
  return reverse_off
end

--- Unsets the reverse attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.reverse_off()
  output.write(M.reverse_offs())
  return true
end

-- lookup brightness levels
local _brightness = utils.make_lookup("brightness level", {
  off = 0,
  low = 1,
  normal = 2,
  high = 3,
  [0] = 0,
  [1] = 1,
  [2] = 2,
  [3] = 3,
  -- common terminal codes
  invisible = 0,
  dim = 1,
  bright = 3,
  bold = 3,
})

-- ansi sequences to apply for each brightness level (always works, does not need a reset)
-- (a reset would also have an effect on underline, blink, and reverse)
local _brightness_sequence = {
  -- 0 = remove bright and dim, apply invisible
  [0] = "\027[22m\027[8m",
  -- 1 = remove bold/dim, remove invisible, set dim
  [1] = "\027[22m\027[28m\027[2m",
  -- 2 = normal, remove dim, bright, and invisible
  [2] = "\027[22m\027[28m",
  -- 3 = remove bold/dim, remove invisible, set bright/bold
  [3] = "\027[22m\027[28m\027[1m",
}

-- same thing, but simplified, if done AFTER an attribute reset
local _brightness_sequence_after_reset = {
  -- 0 = invisible
  [0] = "\027[8m",
  -- 1 = dim
  [1] = "\027[2m",
  -- 2 = normal (no additional attributes needed after reset)
  [2] = "",
  -- 3 = bright/bold
  [3] = "\027[1m",
}

--- Creates an ansi sequence to set the brightness without writing it to the terminal.
-- `brightness` can be one of the following:
--
-- - `0`, `"off"`, or `"invisble"` for invisible
-- - `1`, `"low"`, or `"dim"` for dim
-- - `2`, `"normal"` for normal
-- - `3`, `"high"`, `"bright"`, or `"bold"` for bright
--
-- @tparam string|integer brightness the brightness to set
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.brightnesss(brightness)
  return _brightness_sequence[_brightness[brightness]]
end

--- Sets the brightness and writes it to the terminal.
-- @tparam string|integer brightness the brightness to set
-- @return true
-- @within textcolor
function M.brightness(brightness)
  output.write(M.brightnesss(brightness))
  return true
end

--=============================================================================
-- text_stack: colors & attributes
--=============================================================================
-- Text colors and attributes stack.
-- Stack for managing the text color and attributes.
-- @section textcolor_stack

local function newtext(attr)
  local last = _colorstack[#_colorstack]
  local fg_color = attr.fg or attr.fg_r
  local bg_color = attr.bg or attr.bg_r
  local new = {
    fg         = fg_color        == nil and last.fg         or colorcode(fg_color, attr.fg_g, attr.fg_b, true),
    bg         = bg_color        == nil and last.bg         or colorcode(bg_color, attr.bg_g, attr.bg_b, false),
    brightness = attr.brightness == nil and last.brightness or _brightness[attr.brightness],
    underline  = attr.underline  == nil and last.underline  or (not not attr.underline),
    blink      = attr.blink      == nil and last.blink      or (not not attr.blink),
    reverse    = attr.reverse    == nil and last.reverse    or (not not attr.reverse),
  }
  new.ansi = attribute_reset .. new.fg .. new.bg ..
    _brightness_sequence_after_reset[new.brightness] ..
    (new.underline and underline_on or "") ..
    (new.blink and blink_on or "") ..
    (new.reverse and reverse_on or "")
  -- print("newtext:", (new.ansi:gsub("\27", "\\27")))
  return new
end

--- Creates an ansi sequence to set the text attributes without writing it to the terminal.
-- Only set what you change. Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, with keys:
-- @tparam[opt] string|integer attr.fg the foreground color to set. Base color (string), or extended color (number). Takes precedence of `fg_r`, `fg_g`, `fg_b`.
-- @tparam[opt] integer attr.fg_r the red value of the foreground color to set.
-- @tparam[opt] integer attr.fg_g the green value of the foreground color to set.
-- @tparam[opt] integer attr.fg_b the blue value of the foreground color to set.
-- @tparam[opt] string|integer attr.bg the background color to set. Base color (string), or extended color (number). Takes precedence of `bg_r`, `bg_g`, `bg_b`.
-- @tparam[opt] integer attr.bg_r the red value of the background color to set.
-- @tparam[opt] integer attr.bg_g the green value of the background color to set.
-- @tparam[opt] integer attr.bg_b the blue value of the background color to set.
-- @tparam[opt] string|number attr.brightness the brightness level to set
-- @tparam[opt] boolean attr.underline whether to set underline
-- @tparam[opt] boolean attr.blink whether to set blink
-- @tparam[opt] boolean attr.reverse whether to set reverse
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor_stack
function M.textsets(attr)
  local new = newtext(attr)
  return new.ansi
end

--- Sets the text attributes and writes it to the terminal.
-- Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, see `textsets` for details.
-- @return true
-- @within textcolor_stack
function M.textset(attr)
  output.write(newtext(attr).ansi)
  return true
end

--- Pushes the current attributes onto the stack, and returns an ansi sequence to set the new attributes without writing it to the terminal.
-- Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, see `textsets` for details.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor_stack
function M.textpushs(attr)
  local new = newtext(attr)
  _colorstack[#_colorstack + 1] = new
  return new.ansi
end

--- Pushes the current attributes onto the stack, and writes an ansi sequence to set the new attributes to the terminal.
-- Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, see `textsets` for details.
-- @return true
-- @within textcolor_stack
function M.textpush(attr)
  output.write(M.textpushs(attr))
  return true
end

--- Pops n attributes off the stack (and returns the last one), without writing it to the terminal.
-- @tparam[opt=1] number n number of attributes to pop
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor_stack
function M.textpops(n)
  n = n or 1
  local newtop = math.max(#_colorstack - n, 1)
  for i = newtop + 1, #_colorstack do
    _colorstack[i] = nil
  end
  return _colorstack[#_colorstack].ansi
end

--- Pops n attributes off the stack, and writes the last one to the terminal.
-- @tparam[opt=1] number n number of attributes to pop
-- @return true
-- @within textcolor_stack
function M.textpop(n)
  output.write(M.textpops(n))
  return true
end

--- Re-applies the current attributes (returns it, does not write it to the terminal).
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor_stack
function M.textapplys()
  return _colorstack[#_colorstack].ansi
end

--- Re-applies the current attributes, and writes it to the terminal.
-- @return true
-- @within textcolor_stack
function M.textapply()
  output.write(_colorstack[#_colorstack].ansi)
  return true
end

--=============================================================================
-- line drawing
--=============================================================================
--- Drawing lines.
-- Drawing horizontal and vertical lines.
-- @section lines

--- Creates a sequence to draw a horizontal line without writing it to the terminal.
-- Line is drawn left to right.
-- Returned sequence might be shorter than requested if the character is a multi-byte character
-- and the number of columns is not a multiple of the character width.
-- @tparam number n number of columns to draw
-- @tparam[opt="─"] string char the character to draw
-- @treturn string ansi sequence to write to the terminal
-- @within lines
function M.line_horizontals(n, char)
  char = char or "─"
  local w = sys.utf8cwidth(char)
  return char:rep(math.floor(n / w))
end

--- Draws a horizontal line and writes it to the terminal.
-- Line is drawn left to right.
-- Returned sequence might be shorter than requested if the character is a multi-byte character
-- and the number of columns is not a multiple of the character width.
-- @tparam number n number of columns to draw
-- @tparam[opt="─"] string char the character to draw
-- @return true
-- @within lines
function M.line_horizontal(n, char)
  output.write(M.line_horizontals(n, char))
  return true
end

--- Creates a sequence to draw a vertical line without writing it to the terminal.
-- Line is drawn top to bottom. Cursor is left to the right of the last character (so not below it).
-- @tparam number n number of rows/lines to draw
-- @tparam[opt="│"] string char the character to draw
-- @tparam[opt] boolean lastcolumn whether to draw the last column of the terminal
-- @treturn string ansi sequence to write to the terminal
-- @within lines
function M.line_verticals(n, char, lastcolumn)
  char = char or "│"
  lastcolumn = lastcolumn and 1 or 0
  local w = sys.utf8cwidth(char)
  -- TODO: why do we need 'lastcolumn*2' here???
  return (char .. M.cursor_lefts(w-lastcolumn*2) .. M.cursor_downs(1)):rep(n-1) .. char
end

--- Draws a vertical line and writes it to the terminal.
-- Line is drawn top to bottom. Cursor is left to the right of the last character (so not below it).
-- @tparam number n number of rows/lines to draw
-- @tparam[opt="│"] string char the character to draw
-- @return true
-- @within lines
function M.line_vertical(n, char)
  output.write(M.line_verticals(n, char))
  return true
end

--- Creates a sequence to draw a horizontal line with a title centered in it without writing it to the terminal.
-- Line is drawn left to right. If the width is too small for the title, the title is truncated with "trailing `"..."`.
-- If less than 4 characters are available for the title, the title is omitted alltogether.
-- @tparam number width the total width of the line in columns
-- @tparam[opt=""] string title the title to draw (if empty or nil, only the line is drawn)
-- @tparam[opt="─"] string char the line-character to use
-- @tparam[opt=""] string pre the prefix for the title, eg. "┤ "
-- @tparam[opt=""] string post the postfix for the title, eg. " ├"
-- @treturn string ansi sequence to write to the terminal
-- @within lines
function M.line_titles(width, title, char, pre, post)

  -- TODO: strip any ansi sequences from the title before determining length
  -- such that titles can have multiple colors etc. what if we truncate????

  if title == nil or title == "" then
    return M.line_horizontals(width, char)
  end
  pre = pre or ""
  post = post or ""
  local pre_w = sys.utf8swidth(pre)
  local post_w = sys.utf8swidth(post)
  local title_w = sys.utf8swidth(title)
  local w_for_title = width - pre_w - post_w
  if w_for_title > title_w then
    -- enough space for title
    local p1 = M.line_horizontals(math.floor((w_for_title - title_w) / 2), char) .. pre .. title .. post
    return  p1 .. M.line_horizontals(width - sys.utf8swidth(p1), char)
  elseif w_for_title < 4 then
    -- too little space for title, omit it alltogether
    return M.line_horizontals(width, char)
  elseif w_for_title == title_w then
    -- exact space for title
    return pre .. title .. post
  else -- truncate the title
    w_for_title = w_for_title - 3 -- for "..."
    while title_w == nil or title_w > w_for_title do
      title = title:sub(1, -2) -- drop last byte
      title_w = sys.utf8swidth(title)
    end
    return pre .. title .. "..." .. post
  end
end

--- Draws a horizontal line with a title centered in it and writes it to the terminal.
-- Line is drawn left to right. If the width is too small for the title, the title is truncated with "trailing `"..."`.
-- If less than 4 characters are available for the title, the title is omitted alltogether.
-- @tparam string title the title to draw
-- @tparam number width the total width of the line in columns
-- @tparam[opt="─"] string char the line-character to use
-- @tparam[opt=""] string pre the prefix for the title, eg. "┤ "
-- @tparam[opt=""] string post the postfix for the title, eg. " ├"
-- @return true
-- @within lines
function M.line_title(title, width, char, pre, post)
  output.write(M.line_titles(title, width, char, pre, post))
  return true
end

--- Table with pre-defined box formats.
-- @table box_fmt
-- @field single Single line box format
-- @field double Double line box format
-- @field copy Function to copy a box format, see `box_fmt.copy` for details
-- @within lines
M.box_fmt = utils.make_lookup("box-format", {
  single = {
    h = "─",
    v = "│",
    tl = "┌",
    tr = "┐",
    bl = "└",
    br = "┘",
    pre = "┤",
    post = "├",
  },
  double = {
    h = "═",
    v = "║",
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
  -- @within lines
  -- @usage -- create new format with spaces around the title
  -- local fmt = t.box_fmt.copy(t.box_fmt.single)
  -- fmt.pre = fmt.pre .. " "
  -- fmt.post = " " .. fmt.post
  copy = function(default)
    return {
      h = default.h,
      v = default.v,
      tl = default.tl,
      tr = default.tr,
      bl = default.bl,
      br = default.br,
      pre = default.pre,
      post = default.post,
    }
  end,
})

--- Creates a sequence to draw a box, without writing it to the terminal.
-- The box is drawn starting from the top-left corner at the current cursor position,
-- after drawing the cursor will be in the same position.
-- @tparam number height the height of the box in rows
-- @tparam number width the width of the box in columns
-- @tparam[opt] table format the format for the box (default is single line), with keys:
-- @tparam[opt=" "] string format.h the horizontal line character
-- @tparam[opt=""] string format.v the vertical line character
-- @tparam[opt=""] string format.tl the top left corner character
-- @tparam[opt=""] string format.tr the top right corner character
-- @tparam[opt=""] string format.bl the bottom left corner character
-- @tparam[opt=""] string format.br the bottom right corner character
-- @tparam[opt=""] string format.pre the title-prefix character(s)
-- @tparam[opt=""] string format.post the left-postfix character(s)
-- @tparam[opt=false] bool clear_flag whether to clear the box contents
-- @tparam[opt=""] string title the title to draw
-- @tparam[opt=false] boolean lastcolumn whether to draw the last column of the terminal
-- @treturn string ansi sequence to write to the terminal
-- @within lines
function M.boxs(height, width, format, clear_flag, title, lastcolumn)
  format = format or M.box_fmt.single
  local v_w = sys.utf8swidth(format.v or "")
  local tl_w = sys.utf8swidth(format.tl or "")
  local tr_w = sys.utf8swidth(format.tr or "")
  local bl_w = sys.utf8swidth(format.bl or "")
  local br_w = sys.utf8swidth(format.br or "")
  local v_line_l = M.line_verticals(height - 2, format.v)
  local v_line_r = v_line_l
  if lastcolumn then
    v_line_r = M.line_verticals(height - 2, format.v, lastcolumn)
  end
  lastcolumn = lastcolumn and 1 or 0

  local r = {
    -- draw top
    format.tl or "",
    M.line_titles(width - tl_w - tr_w, title, format.h or " ", format.pre or "", format.post or ""),
    format.tr or "",
    -- position to draw right, and draw it
    M.cursor_moves(1, -v_w + lastcolumn),
    v_line_r,
    -- position back to top left, and draw left
    M.cursor_moves(-height + 3, -width + lastcolumn),
    v_line_l,
    -- draw bottom
    M.cursor_moves(1, -1),
    format.bl or "",
    M.line_horizontals(width - bl_w - br_w, format.h or " "),
    format.br or "",
    -- return to top left
    M.cursor_moves(-height + 1, -width + lastcolumn),
  }
  if clear_flag then
    local l = #r
    r[l+1] = M.cursor_moves(1, v_w)
    r[l+2] = clear.box_seq(height - 2, width - 2 * v_w)
    r[l+3] = M.cursor_moves(-1, -v_w)
  end
  return table.concat(r)
end

--- Draws a box and writes it to the terminal.
-- @tparam number height the height of the box in rows
-- @tparam number width the width of the box in columns
-- @tparam table format the format for the box, see `boxs` for details.
-- @tparam bool clear_flag whether to clear the box contents
-- @tparam[opt=""] string title the title to draw
-- @tparam[opt] boolean lastcolumn whether to draw the last column of the terminal
-- @return true
-- @within lines
function M.box(height, width, format, clear_flag, title, lastcolumn)
  output.write(M.boxs(height, width, format, clear_flag, title, lastcolumn))
  return true
end

--=============================================================================
-- terminal initialization, shutdown and miscellanea
--=============================================================================
--- Initialization.
-- Initialization, termination and miscellaneous functions.
-- @section initialization

--- Returns a string sequence to make the terminal beep.
-- @treturn string ansi sequence to write to the terminal
function M.beeps()
  return "\a"
end

--- Write a sequence to the terminal to make it beep.
-- @return true
function M.beep()
  output.write(M.beep())
  return true
end

do
  local termbackup
  local reset = "\27[0m"
  local savescreen = "\27[?1049h" -- save cursor pos + switch to alternate screen buffer
  local restorescreen = "\27[?1049l" -- restore cursor pos + switch to main screen buffer

  --- Returns whether the terminal has been initialized and is ready for use.
  -- @treturn boolean true if the terminal has been initialized
  function M.ready()
    return termbackup ~= nil
  end

  --- Initializes the terminal for use.
  -- Makes a backup of the current terminal settings.
  -- Sets input to non-blocking, disables canonical mode and echo, and enables ANSI processing.
  -- The preferred way to initialize the terminal is through `initwrap`, since that ensures settings
  -- are properly restored in case of an error, and don't leave the terminal in an inconsistent state
  -- for the user after exit.
  -- @tparam[opt] table opts options table, with keys:
  -- @tparam[opt=false] boolean opts.displaybackup if true, the current terminal display is also
  -- backed up (by switching to the alternate screen buffer).
  -- @tparam[opt=io.stderr] filehandle opts.filehandle the stream to use for output
  -- @tparam[opt=sys.sleep] function opts.bsleep the blocking sleep function to use.
  -- This should never be set to a yielding sleep function! This function
  -- will be used by the `terminal.write` and `terminal.print` to prevent buffer-overflows and
  -- truncation when writing to the terminal. And by `cursor_get` when reading the cursor position.
  -- @tparam[opt=sys.sleep] function opts.sleep the default sleep function to use for `readansi`.
  -- In an async application (coroutines), this should be a yielding sleep function, eg. `copas.pause`.
  -- @return true
  -- @within initialization
  function M.initialize(opts)
    assert(not M.ready(), "terminal already initialized")

    opts = opts or {}
    assert(type(opts) == "table", "expected opts to be a table, got " .. type(opts))

    local filehandle = opts.filehandle or io.stderr
    assert(io.type(filehandle) == 'file', "invalid opts.filehandle")
    t = filehandle

    bsleep = opts.bsleep or sys.sleep
    assert(type(bsleep) == "function", "invalid opts.bsleep function, expected a function, got " .. type(opts.bsleep))
    input.set_bsleep(bsleep)
    output.set_bsleep(bsleep)

    asleep = opts.sleep or sys.sleep
    assert(type(asleep) == "function", "invalid opts.sleep function, expected a function, got " .. type(opts.sleep))
    input.set_sleep(asleep)

    termbackup = sys.termbackup()
    if opts.displaybackup then
      output.write(savescreen)
      termbackup.displaybackup = true
    end

    -- set Windows output to UTF-8
    sys.setconsoleoutputcp(65001)

    -- setup Windows console to handle ANSI processing, disable echo and line input (canonical mode)
    sys.setconsoleflags(io.stdout, sys.getconsoleflags(io.stdout) + sys.COF_VIRTUAL_TERMINAL_PROCESSING)
    sys.setconsoleflags(io.stdin, sys.getconsoleflags(io.stdin) + sys.CIF_VIRTUAL_TERMINAL_INPUT - sys.CIF_ECHO_INPUT - sys.CIF_LINE_INPUT)

    -- setup Posix terminal to disable canonical mode and echo
    sys.tcsetattr(io.stdin, sys.TCSANOW, {
      lflag = sys.tcgetattr(io.stdin).lflag - sys.L_ICANON - sys.L_ECHO,
    })
    -- setup stdin to non-blocking mode
    sys.setnonblock(io.stdin, true)

    return true
  end

  --- Shuts down the terminal, restoring the terminal settings.
  -- @return true
  -- @within initialization
  function M.shutdown()
    assert(M.ready(), "terminal not initialized")

    -- restore all stacks
    local r,c = M.cursor_get() -- Mac: scroll-region reset changes cursor pos to 1,1, so store it
    output.write(
      M.shape_pops(math.huge),
      M.visible_pops(math.huge),
      M.textpops(math.huge),
      scroll.scroll_pops(math.huge),
      M.cursor_sets(r,c) -- restore cursor pos
    )
    t:flush()

    if termbackup.displaybackup then
      output.write(restorescreen)
      t:flush()
    end
    output.write(reset)
    t:flush()

    sys.termrestore(termbackup)

    t = nil
    asleep = nil
    bsleep = nil
    termbackup = nil

    return true
  end
end

--- Wrap a function in `initialize` and `shutdown` calls.
-- When an error occurs, and the application exits, the terminal might not be properly shut down.
-- This function wraps a function in calls to `initialize` and `shutdown`, ensuring the terminal is properly shut down.
-- @tparam[opt] table opts options table, to pass to `initialize`.
-- @tparam function main the function to wrap
-- @param ... any parameters to pass to the main function
-- @treturn any the return values of the wrapped function, or nil+err in case of an error
-- @within initialization
-- @usage local function main(param1, param2)
--   -- your main app functionality here
--
--   return true -- return truthy to pass assertion below
-- end
--
-- local opts = {
--   filehandle = io.stderr,
--   displaybackup = true,
-- }
-- assert(t.initwrap(opts, main, "one", "two")) -- assert to rethrow any error after termimal restore
function M.initwrap(opts, main, ...)
  assert(type(main) == "function", "expected main to be a function, got " .. type(main))
  M.initialize(opts)

  local results
  local ok, err = xpcall(function(...)
    results = pack(main(...))
  end, debug.traceback, ...)

  M.shutdown()

  if not ok then
    return nil, err
  end
  return unpack(results)
end

return M