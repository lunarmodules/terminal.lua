local output = require "terminal.output"

local M = {}

-- Creates an ANSI sequence to clear the screen without writing it to the terminal.
function M.clears()
  return "\27[2J"
end

-- Clears the screen and writes it to the terminal.
function M.clear()
  output.write(M.clears())
  return true
end

-- Creates an ANSI sequence to clear the screen from cursor to left and top without writing.
function M.clear_tops()
  return "\27[1J"
end

-- Clears from cursor to the left and top.
function M.clear_top()
  output.write(M.clear_tops())
  return true
end

-- Creates an ANSI sequence to clear from cursor to right and bottom.
function M.clear_bottoms()
  return "\27[0J"
end

-- Clears from cursor to the right and bottom.
function M.clear_bottom()
  output.write(M.clear_bottoms())
  return true
end

-- Creates an ANSI sequence to clear the line without writing.
function M.clear_lines()
  return "\27[2K"
end

-- Clears the current line.
function M.clear_line()
  output.write(M.clear_lines())
  return true
end

-- Creates an ANSI sequence to clear from cursor to start of the line.
function M.clear_starts()
  return "\27[1K"
end

-- Clears from cursor to start of the line.
function M.clear_start()
  output.write(M.clear_starts())
  return true
end

-- Creates an ANSI sequence to clear from cursor to end of the line.
function M.clear_ends()
  return "\27[0K"
end

-- Clears from cursor to end of the line.
function M.clear_end()
  output.write(M.clear_ends())
  return true
end

-- Creates an ANSI sequence to clear a box from the cursor position.
function M.clear_boxs(height, width)
  local line = (" "):rep(width) .. cursor.cursor_lefts(width)
  local line_next = line .. cursor.cursor_downs()
  return line_next:rep(height - 1) .. line .. cursor.cursor_ups(height - 1)
end

-- Clears a box from the cursor position.
function M.clear_box(height, width)
  output.write(M.clear_boxs(height, width))
  return true
end

return M
