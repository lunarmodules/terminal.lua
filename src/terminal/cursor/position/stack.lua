--- Cursor position stack.
-- Managing the cursor position based on a stack.
-- @module terminal.cursor.position.stack
local M = {}
package.loaded["terminal.cursor.position.stack"] = M -- Register the module early to avoid circular dependencies
local pos = require "terminal.cursor.position"
local output = require("terminal.output")



local _positionstack = {}



--- Pushes the current cursor position onto the stack, and returns an ansi sequence to move to the new position (if applicable) without writing it to the terminal.
-- Calls `position.get` under the hood.
-- @tparam[opt] number new_row
-- @tparam[opt] number new_column
-- @treturn string ansi sequence to write to the terminal, or an empty string if no position is given
-- @within Sequences
function M.push_seq(new_row, new_column)
  local r, c = pos.get()
  -- ignore the error, since we need to keep the stack in sync for pop/push operations
  _positionstack[#_positionstack + 1] = { r, c }
  if new_row or new_column then
    return pos.set_seq(new_row, new_column)
  end
  return ""
end



--- Pushes the current cursor position onto the stack, and writes an ansi sequence to move to the new position (if applicable) to the terminal.
-- Calls `position.get` under the hood.
-- @tparam[opt] number new_row
-- @tparam[opt] number new_column
-- @return true
function M.push(new_row, new_column)
  output.write(M.push_seq(new_row, new_column))
  return true
end



--- Pops the last n cursor positions off the stack, and returns an ansi sequence to move to
-- the last one without writing it to the terminal.
-- @tparam[opt=1] number n number of positions to pop
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.pop_seq(n)
  n = n or 1
  local entry
  while n > 0 do
    entry = table.remove(_positionstack)
    n = n - 1
  end
  if not entry then
    return ""
  end
  return pos.set_seq(entry[1], entry[2])
end



--- Pops the last n cursor positions off the stack, and writes an ansi sequence to move to
-- the last one to the terminal.
-- @tparam[opt=1] number n number of positions to pop
-- @return true
function M.pop(n)
  output.write(M.pop_seq(n))
  return true
end



return M
