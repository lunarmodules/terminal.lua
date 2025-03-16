--- Module to manage scroll-regions and scrolling.
-- Provides functions to manage scroll-regions and perform scrolling operations in the terminal.
-- @module terminal.scroll
local output = require "terminal.output"

local M = {}

-- Import resolve_index and get_height from the main terminal module
local resolve_index = require("terminal").resolve_index
local get_height = require("terminal").get_height

-- Internal scroll reset sequence
local _scroll_reset = "\27[r"

-- Stack to keep track of scroll regions
local _scrollstack = {
  _scroll_reset,
}

--=============================================================================
-- Scroll Region Management (Non-Stack)
--=============================================================================

--- Creates an ANSI sequence to set the scroll region without writing.
-- @tparam[opt] number top Top row of the scroll region.
-- @tparam[opt] number bottom Bottom row of the scroll region.
-- @treturn string ANSI sequence to set the scroll region.
function M.scroll_regions(top, bottom)
  if not top and not bottom then
    return _scroll_reset
  end
  return "\27[" .. tostring(top) .. ";" .. tostring(bottom) .. "r"
end

--- Sets the scroll region and writes it to the terminal.
-- Negative indices are supported, counting from the bottom of the screen.
-- For example, `-1` refers to the last row, `-2` refers to the second-to-last row, etc.
-- @tparam number start_row The first row of the scroll region (can be negative).
-- @tparam number end_row The last row of the scroll region (can be negative).
-- @return true
-- @within scroll_region
function M.scroll_region(start_row, end_row)
  -- Input validation
  assert(type(start_row) == "number", "start_row must be a number")
  assert(type(end_row) == "number", "end_row must be a number")

  -- Resolve negative indices
  start_row = resolve_index(start_row, get_height())
  end_row = resolve_index(end_row, get_height())

  -- Ensure start_row is less than or equal to end_row
  assert(start_row <= end_row, "start_row must be less than or equal to end_row")

  output.write("\27[" .. tostring(start_row) .. ";" .. tostring(end_row) .. "r")
  return true
end

--=============================================================================
-- Basic Scrolling (Without Stack)
--=============================================================================

--- Creates an ANSI sequence to scroll up without writing to the terminal.
-- @tparam[opt=1] number n Number of lines to scroll up.
-- @treturn string ANSI sequence to scroll up.
function M.scroll_ups(n)
  n = n or 1
  return "\27[" .. tostring(n) .. "S"
end

--- Scrolls the screen up and writes it to the terminal.
-- @tparam[opt=1] number n Number of lines to scroll up.
-- @return true
function M.scroll_up(n)
  output.write(M.scroll_ups(n))
  return true
end

--- Creates an ANSI sequence to scroll down without writing to the terminal.
-- @tparam[opt=1] number n Number of lines to scroll down.
-- @treturn string ANSI sequence to scroll down.
function M.scroll_downs(n)
  n = n or 1
  return "\27[" .. tostring(n) .. "T"
end

--- Scrolls the screen down and writes it to the terminal.
-- @tparam[opt=1] number n Number of lines to scroll down.
-- @return true
function M.scroll_down(n)
  output.write(M.scroll_downs(n))
  return true
end

--- Creates an ANSI sequence to scroll vertically without writing to the terminal.
-- @tparam[opt=0] number n Number of lines to scroll (negative for up, positive for down).
-- @treturn string ANSI sequence for vertical scroll.
function M.scrolls(n)
  if n == 0 or n == nil then
    return ""
  end
  return "\27[" .. (n < 0 and (tostring(-n) .. "S") or (tostring(n) .. "T"))
end

--- Scrolls vertically (up/down) and writes it to the terminal.
-- @tparam[opt=0] number n Number of lines to scroll (negative for up, positive for down).
-- @return true
function M.scroll(n)
  output.write(M.scrolls(n))
  return true
end

--=============================================================================
-- Scroll Region Stack Management
--=============================================================================

--- Returns the ANSI sequence of the current scroll region (without writing).
-- @treturn string ANSI sequence of the current scroll region.
function M.scroll_applys()
  return _scrollstack[#_scrollstack]
end

--- Applies the scroll region at the top of the stack and writes it to the terminal.
-- @return true
function M.scroll_apply()
  output.write(M.scroll_applys())
  return true
end

--- Pushes a new scroll region onto the stack without writing it.
-- Negative indices are supported, counting from the bottom of the screen.
-- @tparam[opt] number top Top row of the scroll region (can be negative).
-- @tparam[opt] number bottom Bottom row of the scroll region (can be negative).
-- @treturn string ANSI sequence of the new scroll region.
function M.scroll_pushs(top, bottom)
  if top and bottom then
    top = resolve_index(top, get_height())
    bottom = resolve_index(bottom, get_height())
  end
  _scrollstack[#_scrollstack + 1] = M.scroll_regions(top, bottom)
  return M.scroll_applys()
end

--- Pushes a new scroll region onto the stack and writes it to the terminal.
-- Negative indices are supported, counting from the bottom of the screen.
-- @tparam[opt] number top Top row of the scroll region (can be negative).
-- @tparam[opt] number bottom Bottom row of the scroll region (can be negative).
-- @return true
function M.scroll_push(top, bottom)
  output.write(M.scroll_pushs(top, bottom))
  return true
end

--- Pops `n` scroll regions off the stack (without writing).
-- @tparam[opt=1] number n Number of scroll regions to pop.
-- @treturn string ANSI sequence of the new top of the stack.
function M.scroll_pops(n)
  local new_top = math.max(#_scrollstack - (n or 1), 1)
  for i = new_top + 1, #_scrollstack do
    _scrollstack[i] = nil
  end
  return M.scroll_applys()
end

--- Pops `n` scroll regions off the stack and writes the result to the terminal.
-- @tparam[opt=1] number n Number of scroll regions to pop.
-- @return true
function M.scroll_pop(n)
  output.write(M.scroll_pops(n))
  return true
end

return M
