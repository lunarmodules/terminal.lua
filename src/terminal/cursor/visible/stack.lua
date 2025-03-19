--- Cursor visibility stack.
-- Managing the visibility of the cursor based on a stack. Since the
-- current visibility cannot be requested, using stacks allows the user to revert to
-- a previous state since the stacks keeps track of that.
-- It does however require the user to use balanced operations; `push`/`pop`.
-- @module terminal.cursor.visible.stack
local M = {}
package.loaded["terminal.cursor.visible.stack"] = M -- Register the module early to avoid circular dependencies
local visible = require "terminal.cursor.visible"
local output = require("terminal.output")



local _visible_stack = {
  true
}



--- Returns the ansi sequence to show/hide the cursor at the top of the stack without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.applys()
  return visible.sets(_visible_stack[#_visible_stack])
end



--- Returns the ansi sequence to show/hide the cursor at the top of the stack, and writes it to the terminal.
-- @return true
function M.apply()
  output.write(M.applys())
  return true
end



--- Pushes a cursor visibility onto the stack (and returns it), without writing it to the terminal.
-- @tparam[opt=true] boolean v true to show, false to hide
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.pushs(v)
  _visible_stack[#_visible_stack + 1] = (v ~= false)
  return M.applys()
end



--- Pushes a cursor visibility onto the stack, and writes it to the terminal.
-- @tparam[opt=true] boolean v true to show, false to hide
-- @return true
function M.push(v)
  output.write(M.pushs(v))
  return true
end



--- Pops `n` cursor visibility(ies) off the stack (and returns the last one), without writing it to the terminal.
-- @tparam[opt=1] number n number of visibilities to pop
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.pops(n)
  local new_last = math.max(#_visible_stack - (n or 1), 1)
  for i = new_last + 1, #_visible_stack do
    _visible_stack[i] = nil
  end
  return M.applys()
end



--- Pops `n` cursor visibility(ies) off the stack, and writes the last one to the terminal.
-- @tparam[opt=1] number n number of visibilities to pop
-- @return true
function M.pop(n)
  output.write(M.pops(n))
  return true
end



return M
