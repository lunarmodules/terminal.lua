--- Terminal cursor visibility module.
-- Provides utilities for cursor visibility in terminals.
-- @module terminal.cursor.visible
local M = {}
package.loaded["terminal.cursor.visible"] = M -- Register the module early to avoid circular dependencies


local output = require("terminal.output")


--=============================================================================
-- cursor visibility
--=============================================================================

local cursor_hide = "\27[?25l"
local cursor_show = "\27[?25h"



--- Returns the ansi sequence to show/hide the cursor without writing it to the terminal.
-- @tparam[opt=true] boolean visible true to show, false to hide
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.set_seq(visible)
  return visible == false and cursor_hide or cursor_show
end



--- Shows or hides the cursor and writes it to the terminal.
-- @tparam[opt=true] boolean visible true to show, false to hide
-- @return true
function M.set(visible)
  output.write(M.set_seq(visible))
  return true
end


-- require late, because it calls into functions in this module
M.stack = require "terminal.cursor.visible.stack"

return M
