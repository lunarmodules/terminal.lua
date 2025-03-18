--- Terminal Scroll Module
-- Provides utilities for handling scroll regions in terminals.
-- @module scroll
local M = {}
local output = require("terminal.output")

-- Register the module early to avoid circular dependencies
package.loaded["terminal.scroll"] = M

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

--- Creates an ANSI sequence to reset the scroll region to default.
-- @treturn string The ANSI sequence for resetting the scroll region.
function M.regions(top, bottom)
  if not top and not bottom then
    return M.resets()
  end
  return "\27[" .. tostring(top) .. ";" .. tostring(bottom) .. "r"
end

-- Sets the scroll region and writes the ANSI sequence to the terminal.
-- @tparam number top The top margin of the scroll region.
-- @tparam number bottom The bottom margin of the scroll region.
-- @treturn true Always returns true after setting the scroll region.
function M.region(top, bottom)
  output.write(M.regions(top, bottom))
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
  output.write(M.scrolls(n))
  return true
end

-- Load stack module **after registering everything** to avoid circular dependency
require("terminal.scroll.stack")

return M
