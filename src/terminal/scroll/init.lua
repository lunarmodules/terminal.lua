--- Terminal scroll module.
-- Provides utilities to handle scroll-regions and scrolling in terminals.
-- @module terminal.scroll
local M = {}
package.loaded["terminal.scroll"] = M -- Register the module early to avoid circular dependencies

local sys = require "system"
local output = require("terminal.output")
local utils = require("terminal.utils")

--- Function to return the default scroll reset sequence
-- @treturn string The ANSI sequence for resetting the scroll region.
function M.resets()
  return "\27[r"
end

--- Applies the default scroll reset sequence by writing it to the terminal.
-- @treturn true Always returns true after applying.
function M.reset()
  output.write(M.resets())
  return true
end

--- Creates an ANSI sequence to set the scroll region without writing to the terminal.
-- Negative indices are supported, counting from the bottom of the screen.
-- For example, `-1` refers to the last row, `-2` refers to the second-to-last row, etc.
-- @tparam number start_row The first row of the scroll region (can be negative).
-- @tparam number end_row The last row of the scroll region (can be negative).
-- @treturn string The ANSI sequence for setting the scroll region.
function M.sets(start_row, end_row)
  -- Resolve negative indices
  local rows, _ = sys.termsize()
  start_row = utils.resolve_index(start_row, rows)
  end_row = utils.resolve_index(end_row, rows)
  return "\27[" .. tostring(start_row) .. ";" .. tostring(end_row) .. "r"
end

-- Sets the scroll region and writes the ANSI sequence to the terminal.
-- Negative indices are supported, counting from the bottom of the screen.
-- For example, `-1` refers to the last row, `-2` refers to the second-to-last row, etc.
-- @tparam number start_row The first row of the scroll region (can be negative).
-- @tparam number end_row The last row of the scroll region (can be negative).
-- @treturn true Always returns true after setting the scroll region.
function M.set(start_row, end_row)
  output.write(M.sets(start_row, end_row))
  return true
end

-- Creates an ANSI sequence to scroll up by a specified number of lines.
-- @tparam[opt=1] number n The number of lines to scroll up.
-- @treturn string The ANSI sequence for scrolling up.
function M.ups(n)
  n = n or 1
  return "\27[" .. tostring(n) .. "S"
end

--- Scrolls up by a specified number of lines and writes the sequence to the terminal.
-- @tparam[opt=1] number n The number of lines to scroll up.
-- @treturn true Always returns true after scrolling.
function M.up(n)
  output.write(M.ups(n))
  return true
end

--- Creates an ANSI sequence to scroll down by a specified number of lines.
-- @tparam[opt=1] number n The number of lines to scroll down.
-- @treturn string The ANSI sequence for scrolling down.
function M.downs(n)
  n = n or 1
  return "\27[" .. tostring(n) .. "T"
end

--- Scrolls down by a specified number of lines and writes the sequence to the terminal.
-- @tparam[opt=1] number n The number of lines to scroll down.
-- @treturn true Always returns true after scrolling.
function M.down(n)
  output.write(M.downs(n))
  return true
end

--- Creates an ANSI sequence to scroll vertically by a specified number of lines.
-- Positive values scroll down, negative values scroll up.
-- @tparam number n The number of lines to scroll (positive for down, negative for up).
-- @treturn string The ANSI sequence for vertical scrolling.
function M.verticals(n)
  if n == 0 or n == nil then
    return ""
  end
  return "\27[" .. (n < 0 and (tostring(-n) .. "S") or (tostring(n) .. "T"))
end

--- Scrolls vertically by a specified number of lines and writes the sequence to the terminal.
-- @tparam number n The number of lines to scroll (positive for down, negative for up).
-- @treturn true Always returns true after scrolling.
function M.vertical(n)
  output.write(M.verticals(n))
  return true
end

-- Load stack module **after registering everything** since it will call into
-- this module.
M.stack = require("terminal.scroll.stack")

return M
