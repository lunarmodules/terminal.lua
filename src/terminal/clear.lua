--- Clear Module.
-- Provides functions to clear various parts of the terminal screen.
-- @module clear

local terminal = require "terminal"
local output = require "terminal.output"

local M = {}

--- Creates an ANSI sequence to clear the entire screen without writing it to the terminal.
-- @treturn string The ANSI sequence for clearing the entire screen.
function M.clears()
  return "\27[2J"
end

--- Clears the entire screen by writing the ANSI sequence to the terminal.
-- @treturn true Always returns true after clearing.
function M.clear()
  output.write(M.clears())
  return true
end

--- Creates an ANSI sequence to clear the screen from cursor to top-left without writing.
-- @treturn string The ANSI sequence for clearing to the top.
function M.clear_tops()
  return "\27[1J"
end

--- Clears the screen from the cursor position to the top-left and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.clear_top()
  output.write(M.clear_tops())
  return true
end

--- Creates an ANSI sequence to clear the screen from cursor to bottom-right without writing.
-- @treturn string The ANSI sequence for clearing to the bottom.
function M.clear_bottoms()
  return "\27[0J"
end

--- Clears the screen from the cursor position to the bottom-right and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.clear_bottom()
  output.write(M.clear_bottoms())
  return true
end

--- Creates an ANSI sequence to clear the current line without writing.
-- @treturn string The ANSI sequence for clearing the entire line.
function M.clear_lines()
  return "\27[2K"
end

--- Clears the current line and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.clear_line()
  output.write(M.clear_lines())
  return true
end

--- Creates an ANSI sequence to clear from cursor to start of the line without writing.
-- @treturn string The ANSI sequence for clearing to the start of the line.
function M.clear_starts()
  return "\27[1K"
end

--- Clears from cursor to start of the line and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.clear_start()
  output.write(M.clear_starts())
  return true
end

--- Creates an ANSI sequence to clear from cursor to end of the line without writing.
-- @treturn string The ANSI sequence for clearing to the end of the line.
function M.clear_ends()
  return "\27[0K"
end

--- Clears from cursor to end of the line and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.clear_end()
  output.write(M.clear_ends())
  return true
end

--- Creates an ANSI sequence to clear a box from the cursor position without writing.
-- @tparam number height The height of the box to clear.
-- @tparam number width The width of the box to clear.
-- @treturn string The ANSI sequence for clearing the box.
function M.clear_boxs(height, width)
  local line = (" "):rep(width) .. terminal.cursor_lefts(width)
  local line_next = line .. terminal.cursor_downs()
  return line_next:rep(height - 1) .. line .. terminal.cursor_ups(height - 1)
end

--- Clears a box from the cursor position and writes it to the terminal.
-- @tparam number height The height of the box to clear.
-- @tparam number width The width of the box to clear.
-- @treturn true Always returns true after clearing.
function M.clear_box(height, width)
  output.write(M.clear_boxs(height, width))
  return true
end

return M
