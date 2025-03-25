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
-- @within Sequences
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
-- @within Sequences
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
-- @within Sequences
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
-- @within Sequences
function M.line_seq()
  return "\27[2K"
end

--- Clears the current line and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.line()
  output.write(M.line_seq())
  return true
end

--- Creates an ANSI sequence to clear from cursor to begin of the line (BOL) without writing.
-- @treturn string The ANSI sequence for clearing to the start of the line.
-- @within Sequences
function M.bol_seq()
  return "\27[1K"
end

--- Clears from cursor to begin of the line (BOL) and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.bol()
  output.write(M.bol_seq())
  return true
end

--- Creates an ANSI sequence to clear from cursor to end of the line (EOL) without writing.
-- @treturn string The ANSI sequence for clearing to the end of the line.
-- @within Sequences
function M.eol_seq()
  return "\27[0K"
end

--- Clears from cursor to end of the line (EOL) and writes to the terminal.
-- @treturn true Always returns true after clearing.
function M.eol()
  output.write(M.	eol_seq())
  return true
end

--- Creates an ANSI sequence to clear a box without writing.
-- The sequence starts at the current cursor position, and returns the cursor there.
-- If either height or width is less than 1, the function returns an empty string.
-- @tparam number height The height of the box to clear.
-- @tparam number width The width of the box to clear.
-- @treturn string The ANSI sequence for clearing the box.
-- @within Sequences
function M.box_seq(height, width)
  if height < 1 or width < 1 then
    return ""
  end
  local line = (" "):rep(width) .. terminal.cursor.position.left_seq(width)
  local line_next = line .. terminal.cursor.position.down_seq()
  local res = line_next:rep(height - 1) .. line
  if height == 1 then
    return res
  end
  return res .. terminal.cursor.position.up_seq(height - 1)
end

--- Clears a box and writes it to the terminal.
-- The sequence starts at the current cursor position, and returns the cursor there.
-- If either height or width is less than 1, the function writes an empty string.
-- @tparam number height The height of the box to clear.
-- @tparam number width The width of the box to clear.
-- @treturn true Always returns true after clearing.
function M.box(height, width)
  output.write(M.box_seq(height, width))
  return true
end

return M
