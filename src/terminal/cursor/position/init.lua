--- Terminal cursor position module.
-- Provides utilities for cursor positioning in terminals.
-- @module terminal.cursor.position

local M = {}
package.loaded["terminal.cursor.position"] = M -- Register the module early to avoid circular dependencies
M.stack = require "terminal.cursor.position.stack"

local output = require("terminal.output")
local input = require("terminal.input")
local utils = require("terminal.utils")
local sys = require("system")



local unpack do
  -- nil-safe versions of pack/unpack
  local oldunpack = _G.unpack or table.unpack -- luacheck: ignore
  --pack = function(...) return { n = select("#", ...), ... } end
  unpack = function(t, i, j) return oldunpack(t, i or 1, j or t.n or #t) end
end



--- returns the sequence for requesting cursor position as a string.
-- If you need to get the current position, use `get` instead.
-- @treturn string the sequence for requesting cursor position
-- @within Sequences
function M.querys()
  return "\27[6n"
end



--- write the sequence for requesting cursor position, without flushing.
-- If you need to get the current position, use `get` instead.
function M.query()
  output.write(M.querys())
end



--- Requests the current cursor position from the terminal.
-- Will read entire keyboard buffer to empty it, then request the cursor position.
-- The output buffer will be flushed.
-- In case of a keyboard error, the error will be returned here, but also by
-- `readansi` on a later call, because readansi retains the proper order of keyboard
-- input, whilst this function buffers input.
--
-- **This function is relatively slow!** It will block until the terminal responds.
-- A least 1 sleep step will be executed, which is 20+ milliseconds usually (depends
-- on the platform). So keeping track of the cursor is more efficient than calling
-- this many times.
-- @treturn[1] number row
-- @treturn[1] number column
-- @treturn[2] nil
-- @treturn[2] string error message in case of a keyboard read error
function M.get()
  -- first empty keyboard buffer
  local ok, err = input.preread()
  if not ok then
    return nil, err
  end

  -- request cursor position
  M.query()
  output.flush()

  -- get position
  local r, err = input.read_cursor_pos(1)
  if not r then
    return nil, err
  end
  return unpack(r[1])
end



--- Creates ansi sequence to set the cursor position without writing it to the terminal.
-- @tparam number row
-- @tparam number column
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.sets(row, column)
  -- Resolve negative indices
  local rows, cols = sys.termsize()
  row = utils.resolve_index(row, rows)
  column = utils.resolve_index(column, cols)
  return "\27[" .. tostring(row) .. ";" .. tostring(column) .. "H"
end



--- Sets the cursor position and writes it to the terminal.
-- @tparam number row
-- @tparam number column
-- @return true
function M.set(row, column)
  output.write(M.sets(row, column))
  return true
end



--- Returns the ansi sequence to backup the current cursor position (in terminal storage, not stacked).
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.backups()
  return "\27[s"
end



--- Writes the ansi sequence to backup the current cursor position (in terminal storage, not stacked) to the terminal.
-- @return true
function M.backup()
  output.write(M.backups())
  return true
end



--- Returns the ansi sequence to restore the cursor position (from the terminal storage, not stacked).
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.restores()
  return "\27[u"
end



--- Writes the ansi sequence to restore the cursor position (from the terminal storage, not stacked) to the terminal.
-- @return true
function M.restore()
  output.write(M.restores())
  return true
end



--- Creates an ansi sequence to move the cursor up without writing it to the terminal.
-- @tparam[opt=1] number n number of rows to move up
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.ups(n)
  n = n or 1
  return "\27["..tostring(n).."A"
end



--- Moves the cursor up and writes it to the terminal.
-- @tparam[opt=1] number n number of rows to move up
-- @return true
function M.up(n)
  output.write(M.ups(n))
  return true
end



--- Creates an ansi sequence to move the cursor down without writing it to the terminal.
-- @tparam[opt=1] number n number of rows to move down
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.downs(n)
  n = n or 1
  return "\27["..tostring(n).."B"
end



--- Moves the cursor down and writes it to the terminal.
-- @tparam[opt=1] number n number of rows to move down
-- @return true
function M.down(n)
  output.write(M.downs(n))
  return true
end



--- Creates an ansi sequence to move the cursor vertically without writing it to the terminal.
-- @tparam[opt=1] number n number of rows to move (negative for up, positive for down)
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.verticals(n)
  n = n or 1
  if n == 0 then
    return ""
  end
  return "\27[" .. (n < 0 and (tostring(-n) .. "A") or (tostring(n) .. "B"))
end



--- Moves the cursor vertically and writes it to the terminal.
-- @tparam[opt=1] number n number of rows to move (negative for up, positive for down)
-- @return true
function M.vertical(n)
  output.write(M.verticals(n))
  return true
end



--- Creates an ansi sequence to move the cursor left without writing it to the terminal.
-- @tparam[opt=1] number n number of columns to move left
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.lefts(n)
  n = n or 1
  return "\27["..tostring(n).."D"
end



--- Moves the cursor left and writes it to the terminal.
-- @tparam[opt=1] number n number of columns to move left
-- @return true
function M.left(n)
  output.write(M.lefts(n))
  return true
end



--- Creates an ansi sequence to move the cursor right without writing it to the terminal.
-- @tparam[opt=1] number n number of columns to move right
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.rights(n)
  n = n or 1
  return "\27["..tostring(n).."C"
end



--- Moves the cursor right and writes it to the terminal.
-- @tparam[opt=1] number n number of columns to move right
-- @return true
function M.right(n)
  output.write(M.rights(n))
  return true
end



--- Creates an ansi sequence to move the cursor horizontally without writing it to the terminal.
-- @tparam[opt=1] number n number of columns to move (negative for left, positive for right)
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.horizontals(n)
  n = n or 1
  if n == 0 then
    return ""
  end
  return "\27[" .. (n < 0 and (tostring(-n) .. "D") or (tostring(n) .. "C"))
end



--- Moves the cursor horizontally and writes it to the terminal.
-- @tparam[opt=1] number n number of columns to move (negative for left, positive for right)
-- @return true
function M.horizontal(n)
  output.write(M.horizontals(n))
  return true
end



--- Creates an ansi sequence to move the cursor horizontal and vertical without writing it to the terminal.
-- @tparam[opt=0] number rows number of rows to move (negative for up, positive for down)
-- @tparam[opt=0] number columns number of columns to move (negative for left, positive for right)
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.moves(rows, columns)
  return M.verticals(rows or 0) .. M.horizontals(columns or 0)
end



--- Moves the cursor horizontal and vertical and writes it to the terminal.
-- @tparam[opt=0] number rows number of rows to move (negative for up, positive for down)
-- @tparam[opt=0] number columns number of columns to move (negative for left, positive for right)
-- @return true
function M.move(rows, columns)
  output.write(M.moves(rows, columns))
  return true
end



--- Creates an ansi sequence to move the cursor to a column on the current row without writing it to the terminal.
-- @tparam number column the column to move to
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.columns(column)
  -- TODO: implement negative indices
  return "\27["..tostring(column).."G"
end



--- Moves the cursor to a column on the current row and writes it to the terminal.
-- @tparam number column the column to move to
-- @return true
function M.column(column)
  output.write(M.columns(column))
  return true
end



--- Creates an ansi sequence to move the cursor to a row on the current column without writing it to the terminal.
-- @tparam number row the row to move to
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.rows(row)
  -- TODO: implement negative indices
  return "\27["..tostring(row).."d"
end



--- Moves the cursor to a row on the current column and writes it to the terminal.
-- @tparam number row the row to move to
-- @return true
function M.row(row)
  output.write(M.rows(row))
  return true
end



return M
