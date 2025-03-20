--- Cursor position stack.
-- Managing the cursor position based on a stack.
-- @module terminal.cursor.position.stack
local M = {}
package.loaded["terminal.cursor.position.stack"] = M -- Register the module early to avoid circular dependencies
local pos = require "terminal.cursor.position"
local output = require("terminal.output")



local _positionstack = {}



--- Pushes the current cursor position onto the stack, and returns an ansi sequence to move to
-- the new position without writing it to the terminal.
-- Calls `position.get` under the hood.
-- @tparam number row
-- @tparam number column
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.pushs(row, column)
  local r, c = pos.get()
  -- ignore the error, since we need to keep the stack in sync for pop/push operations
  _positionstack[#_positionstack + 1] = { r, c }
  return pos.sets(row, column)
end



--- Pushes the current cursor position onto the stack, and writes an ansi sequence to move to
-- the new position to the terminal.
-- Calls `position.get` under the hood.
-- @tparam number row
-- @tparam number column
-- @return true
function M.push(row, column)
  output.write(M.pushs(row, column))
  return true
end



--- Pops the last n cursor positions off the stack, and returns an ansi sequence to move to
-- the last one without writing it to the terminal.
-- @tparam[opt=1] number n number of positions to pop
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.pops(n)
  n = n or 1
  local entry
  while n > 0 do
    entry = table.remove(_positionstack)
    n = n - 1
  end
  if not entry then
    return ""
  end
  return pos.sets(entry[1], entry[2])
end



--- Pops the last n cursor positions off the stack, and writes an ansi sequence to move to
-- the last one to the terminal.
-- @tparam[opt=1] number n number of positions to pop
-- @return true
function M.pop(n)
  output.write(M.pops(n))
  return true
end



return M
