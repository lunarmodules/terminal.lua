--- Module for drawing lines.
-- Provides functions to create lines on a terminal screen.
-- @module terminal.draw.line

local M = {}
package.loaded["terminal.draw.line"] = M -- Push in `package.loaded` to avoid circular dependencies

local Sequence = require "terminal.sequence"
local output = require "terminal.output"
local cursor = require "terminal.cursor"
local text = require "terminal.text"
local utils = require "terminal.utils"



--- Creates a sequence to draw a horizontal line without writing it to the terminal.
-- Line is drawn left to right.
-- Returned sequence might be shorter than requested if the character is a multi-byte character
-- and the number of columns is not a multiple of the character width.
-- @tparam number n number of columns to draw
-- @tparam[opt="─"] string char the character to draw
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.horizontal_seq(n, char)
  char = char or "─"
  local w = text.width.utf8cwidth(char)
  return char:rep(math.floor(n / w))
end



--- Draws a horizontal line and writes it to the terminal.
-- Line is drawn left to right.
-- Returned sequence might be shorter than requested if the character is a multi-byte character
-- and the number of columns is not a multiple of the character width.
-- @tparam number n number of columns to draw
-- @tparam[opt="─"] string char the character to draw
-- @return true
function M.horizontal(n, char)
  output.write(M.horizontal_seq(n, char))
  return true
end



--- Creates a sequence to draw a vertical line without writing it to the terminal.
-- Line is drawn top to bottom. Cursor is left to the right of the last character (so not below it).
-- @tparam number n number of rows/lines to draw
-- @tparam[opt="│"] string char the character to draw
-- @tparam[opt] boolean lastcolumn whether to draw the last column of the terminal
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.vertical_seq(n, char, lastcolumn)
  char = char or "│"
  lastcolumn = lastcolumn and 1 or 0
  local w = text.width.utf8cwidth(char)
  -- TODO: why do we need 'lastcolumn*2' here???
  return (char .. cursor.position.left_seq(w-lastcolumn*2) .. cursor.position.down_seq(1)):rep(n-1) .. char
end



--- Draws a vertical line and writes it to the terminal.
-- Line is drawn top to bottom. Cursor is left to the right of the last character (so not below it).
-- @tparam number n number of rows/lines to draw
-- @tparam[opt="│"] string char the character to draw
-- @tparam[opt] boolean lastcolumn whether to draw the last column of the terminal
-- @return true
function M.vertical(n, char, lastcolumn)
  output.write(M.vertical_seq(n, char, lastcolumn))
  return true
end



--- Creates a sequence to draw a horizontal line with a title centered in it without writing it to the terminal.
-- Line is drawn left to right. If the width is too small for the title, the title is truncated.
-- If less than 4 characters are available for the title, the title is omitted alltogether.
-- @tparam number width the total width of the line in columns
-- @tparam[opt=""] string title the title to draw (if empty or nil, only the line is drawn)
-- @tparam[opt="─"] string char the line-character to use
-- @tparam[opt=""] string pre the prefix for the title, eg. "┤ "
-- @tparam[opt=""] string post the postfix for the title, eg. " ├"
-- @tparam[opt="right"] string type the type of truncation to apply, either "left", "right", or "drop", see `utils.truncate_ellipsis` for details
-- @tparam[opt] table title_attr table of attributes for the title, eg. `{ fg = "red", bg = "blue" }`
-- @treturn Sequence|string The sequence to write to the terminal
-- @within Sequences
function M.title_seq(width, title, char, pre, post, type, title_attr)
  if title == nil or title == "" then
    return M.horizontal_seq(width, char)
  end

  pre = pre or ""
  post = post or ""
  local pre_w = text.width.utf8swidth(pre)
  local post_w = text.width.utf8swidth(post)
  local w_for_title = width - pre_w - post_w

  local title, title_w = utils.truncate_ellipsis(w_for_title, title, type)
  if title_w == 0 then
    return M.horizontal_seq(width, char)
  end
  title_w = title_w + pre_w + post_w -- width including prefix and postfix

  local left = math.floor((width - title_w) / 2)
  local right = width - left - title_w
  if not title_attr then
    return M.horizontal_seq(left, char) .. pre .. title .. post .. M.horizontal_seq(right, char)
  else
    return Sequence(
      M.horizontal_seq(left, char),
      pre,
      function() return text.stack.push_seq(title_attr) end,
      title,
      text.stack.pop_seq,
      post,
      M.horizontal_seq(right, char)
    )
  end
end



--- Draws a horizontal line with a title centered in it and writes it to the terminal.
-- Line is drawn left to right. If the width is too small for the title, the title is truncated with "trailing `"..."`.
-- If less than 4 characters are available for the title, the title is omitted alltogether.
-- @tparam string title the title to draw
-- @tparam number width the total width of the line in columns
-- @tparam[opt="─"] string char the line-character to use
-- @tparam[opt=""] string pre the prefix for the title, eg. "┤ "
-- @tparam[opt=""] string post the postfix for the title, eg. " ├"
-- @tparam[opt="right"] string type the type of truncation to apply, either "left", "right", or "drop", see `utils.truncate_ellipsis` for details
-- @tparam[opt] table title_attr table of attributes for the title, eg. `{ fg = "red", bg = "blue" }`
-- @return true
function M.title(title, width, char, pre, post, type, title_attr)
  output.write(M.title_seq(title, width, char, pre, post, type, title_attr))
  return true
end



return M
