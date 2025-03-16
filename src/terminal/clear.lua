--- Module for clearing (parts of) the screen.
-- Provides functions to clear various parts of the terminal screen.
-- @module terminal.clear

local M = {}
-- Push the module table already in `package.loaded` to avoid circular dependencies
package.loaded["terminal.clear"] = M

local terminal = require "terminal"
local output = require "terminal.output"


--- Creates an ANSI sequence to clear the entire screen without writing it to the terminal.
-- @treturn string The ANSI sequence for clearing the entire screen.
function M.screen_seq()
  return "\27[2J"
end

--- Clears the entire screen by writing the ANSI sequence to the terminal.
-- @treturn true Always returns true after clearing.
function M.screen()
  output.write(M.screen_seq())
  return true
end

--- Creates an ANSI sequence to clear the screen from cursor to top-left without writing.
-- @treturn string The ANSI sequence for clearing to the top.
function M.top_seq()
  return "\27[1J"
end

--- Clears the screen from the cursor position to the top-left and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.top()
  output.write(M.top_seq())
  return true
end

--- Creates an ANSI sequence to clear the screen from cursor to bottom-right without writing.
-- @treturn string The ANSI sequence for clearing to the bottom.
function M.bottom_seq()
  return "\27[0J"
end

--- Clears the screen from the cursor position to the bottom-right and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.bottom()
  output.write(M.bottom_seq())
  return true
end

--- Creates an ANSI sequence to clear the current line without writing.
-- @treturn string The ANSI sequence for clearing the entire line.
function M.line_seq()
  return "\27[2K"
end

--- Clears the current line and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.line()
  output.write(M.line_seq())
  return true
end

--- Creates an ANSI sequence to clear from cursor to start of the line without writing.
-- @treturn string The ANSI sequence for clearing to the start of the line.
function M.bol_seq()
  return "\27[1K"
end

--- Clears from cursor to start of the line and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.bol()
  output.write(M.bol_seq())
  return true
end

--- Creates an ANSI sequence to clear from cursor to end of the line without writing.
-- @treturn string The ANSI sequence for clearing to the end of the line.
function M.	eol_seq()
  return "\27[0K"
end

--- Clears from cursor to end of the line and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.eol()
  output.write(M.	eol_seq())
  return true
end

--- Creates an ANSI sequence to clear a box from the cursor position without writing.
-- @tparam number height The height of the box to clear.
-- @tparam number width The width of the box to clear.
-- @treturn string The ANSI sequence for clearing the box.
function M.box_seq(height, width)
  local line = (" "):rep(width) .. terminal.cursor_lefts(width)
  local line_next = line .. terminal.cursor_downs()
  return line_next:rep(height - 1) .. line .. terminal.cursor_ups(height - 1)
end

--- Clears a box from the cursor position and writes it to the terminal.
-- @tparam number height The height of the box to clear.
-- @tparam number width The width of the box to clear.
-- @treturn true Always returns true after clearing.
function M.box(height, width)
  output.write(M.box_seq(height, width))
  return true
end

return M
