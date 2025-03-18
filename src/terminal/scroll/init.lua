--- Terminal Scroll Module
-- Provides utilities for handling scroll regions in terminals.
-- @module terminal.scroll

local M = {}
local output = require("terminal.output")

-- Register the module early to avoid circular dependencies
package.loaded["terminal.scroll"] = M

--- Function to return the default scroll reset sequence
-- @treturn string The ANSI sequence for resetting the scroll region.
function M.reset()
  return "\27[r"
end

--- Creates an ANSI sequence to reset the scroll region to default.
-- @treturn string The ANSI sequence for resetting the scroll region.
function M.regions(top, bottom)
  if not top and not bottom then
    return M.reset()
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
-- @treturn string The ANSI sequence for scroll
