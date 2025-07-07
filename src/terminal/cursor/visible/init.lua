--- Terminal cursor visibility module.
-- Provides utilities for cursor visibility in terminals.
-- @module terminal.cursor.visible
local M = {}
package.loaded["terminal.cursor.visible"] = M -- Register the module early to avoid circular dependencies


local output = require("terminal.output")





local _visible_stack = {
  true
}



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

--- Returns the ansi sequence to show/hide the cursor at the top of the stack without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.apply_seq()
  return M.set_seq(_visible_stack[#_visible_stack])
end



--- Returns the ansi sequence to show/hide the cursor at the top of the stack, and writes it to the terminal.
-- @return true
function M.apply()
  output.write(M.apply_seq())
  return true
end



--- Pushes a cursor visibility onto the stack (and returns it), without writing it to the terminal.
-- @tparam[opt=true] boolean v true to show, false to hide
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.push_seq(v)
  _visible_stack[#_visible_stack + 1] = (v ~= false)
  return M.apply_seq()
end



--- Pushes a cursor visibility onto the stack, and writes it to the terminal.
-- @tparam[opt=true] boolean v true to show, false to hide
-- @return true
function M.push(v)
  output.write(M.push_seq(v))
  return true
end



--- Pops `n` cursor visibility(ies) off the stack (and returns the last one), without writing it to the terminal.
-- @tparam[opt=1] number n number of visibilities to pop
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.pop_seq(n)
  local new_last = math.max(#_visible_stack - (n or 1), 1)
  for i = new_last + 1, #_visible_stack do
    _visible_stack[i] = nil
  end
  return M.apply_seq()
end



--- Pops `n` cursor visibility(ies) off the stack, and writes the last one to the terminal.
-- @tparam[opt=1] number n number of visibilities to pop
-- @return true
function M.pop(n)
  output.write(M.pop_seq(n))
  return true
end

return M
