--- Terminal Scroll Module.
-- Provides utilities for handling scroll regions in terminals.
-- @module scroll
local M = {}
M.output = require("terminal.output")

-- Register in package.loaded with correct name
package.loaded["terminal.scroll"] = M

local _scroll_reset = "\27[r"

--- Creates an ANSI sequence to reset the scroll region to default.
-- @treturn string The ANSI sequence for resetting the scroll region.
function M.scroll_regions(top, bottom)
  if not top and not bottom then
    return _scroll_reset
  end
  return "\27[" .. tostring(top) .. ";" .. tostring(bottom) .. "r"
end

-- Sets the scroll region and writes the ANSI sequence to the terminal.
-- @tparam number top The top margin of the scroll region.
-- @tparam number bottom The bottom margin of the scroll region.
-- @treturn true Always returns true after setting the scroll region.
function M.scroll_region(top, bottom)
  M.output.write(M.scroll_regions(top, bottom))
  return true
end

-- Creates an ANSI sequence to scroll up by a specified number of lines.
-- @tparam[opt=1] number n The number of lines to scroll up.
-- @treturn string The ANSI sequence for scrolling up.
function M.scroll_ups(n)
  n = n or 1
  return "\27[" .. tostring(n) .. "S"
end

--- Scrolls up by a specified number of lines and writes the sequence to the terminal.
-- @tparam[opt=1] number n The number of lines to scroll up.
-- @treturn true Always returns true after scrolling.
function M.scroll_up(n)
  M.output.write(M.scroll_ups(n))
  return true
end

--- Creates an ANSI sequence to scroll down by a specified number of lines.
-- @tparam[opt=1] number n The number of lines to scroll down.
-- @treturn string The ANSI sequence for scrolling down.
function M.scroll_downs(n)
  n = n or 1
  return "\27[" .. tostring(n) .. "T"
end

--- Scrolls down by a specified number of lines and writes the sequence to the terminal.
-- @tparam[opt=1] number n The number of lines to scroll down.
-- @treturn true Always returns true after scrolling.
function M.scroll_down(n)
  M.output.write(M.scroll_downs(n))
  return true
end

--- Creates an ANSI sequence to scroll vertically by a specified number of lines.
-- Positive values scroll down, negative values scroll up.
-- @tparam number n The number of lines to scroll (positive for down, negative for up).
-- @treturn string The ANSI sequence for vertical scrolling.
function M.scrolls(n)
  if n == 0 or n == nil then
    return ""
  end
  return "\27[" .. (n < 0 and (tostring(-n) .. "S") or (tostring(n) .. "T"))
end

--- Scrolls vertically by a specified number of lines and writes the sequence to the terminal.
-- @tparam number n The number of lines to scroll (positive for down, negative for up).
-- @treturn true Always returns true after scrolling.
function M.scroll(n)
  M.output.write(M.scrolls(n))
  return true
end

--- The stack module for handling scroll regions.
M.stack = require("terminal.scroll.stack")

return M
