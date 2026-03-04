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



--- Returns the ansi sequence to show/hide the cursor at the top of the stack without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within Stack
-- @see terminal.cursor.visible.stack.apply_seq
M.apply_seq = M.stack.apply_seq



--- Returns the ansi sequence to show/hide the cursor at the top of the stack, and writes it to the terminal.
-- @return true
-- @within Stack
-- @see terminal.cursor.visible.stack.apply
M.apply = M.stack.apply



--- Pushes a cursor visibility onto the stack (and returns it), without writing it to the terminal.
-- @tparam[opt=true] boolean v true to show, false to hide
-- @treturn string ansi sequence to write to the terminal
-- @within Stack
-- @see terminal.cursor.visible.stack.push_seq
M.push_seq = M.stack.push_seq



--- Pushes a cursor visibility onto the stack, and writes it to the terminal.
-- @tparam[opt=true] boolean v true to show, false to hide
-- @return true
-- @within Stack
-- @see terminal.cursor.visible.stack.push
M.push = M.stack.push



--- Pops `n` cursor visibility(ies) off the stack (and returns the last one), without writing it to the terminal.
-- @tparam[opt=1] number n number of visibilities to pop
-- @treturn string ansi sequence to write to the terminal
-- @within Stack
-- @see terminal.cursor.visible.stack.pop_seq
M.pop_seq = M.stack.pop_seq



--- Pops `n` cursor visibility(ies) off the stack, and writes the last one to the terminal.
-- @tparam[opt=1] number n number of visibilities to pop
-- @return true
-- @within Stack
-- @see terminal.cursor.visible.stack.pop
M.pop = M.stack.pop



return M
