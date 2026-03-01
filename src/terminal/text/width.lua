--- Module for character and string display width in terminal columns.
--
-- Not all characters are displayed with the same width on the terminal.
-- The Unicode standard defines the width of many characters, but not all.
-- Especially the ['ambiguous width'](https://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt)
-- characters can be displayed with different
-- widths especially when used with East Asian languages.
-- The only way to truly know their display width is to write them to the terminal
-- and measure the cursor position change.
--
-- This module implements ambiguous-width configuration and detection (default 1).
-- Preferably, ambiguous width is detected once during terminal initialization.
--
-- The functions `utf8cwidth` and `utf8swidth` can be used to get the display width of characters and strings, respectively.
-- @module terminal.text.width

local M = {}
package.loaded["terminal.text.width"] = M -- Register the module early to avoid circular dependencies


local sys_utf8cwidth = require("system").utf8cwidth
local utf8 = require("utf8") -- explicit lua-utf8 library call, for <= Lua 5.3 compatibility


-- Global variable to use for ambiguous width characters
local ambiguous_width = 1



--- Detects and sets the width of the abiguous width characters.
-- Writes a test character and queries the cursor position. Returns (and sets) the default value 1 if detection fails.
--
-- The preferred way to call this function is during terminal initialization, see `terminal.initialize`.
-- @treturn number 1 or 2
function M.detect_ambiguous_width()
  local t = require("terminal")
  if not t.output.isatty() then
    return 1
  end

  local probe_char = utf8.char(0x00A1)
  local cpr = t.cursor.position.query_seq()
  local cpr_pattern = "^\27%[(%d+);(%d+)R$"

  t.input.preread()
  t.text.stack.push({ brightness = 0 })
  t.output.write(cpr .. probe_char .. cpr)
  t.output.flush()

  local responses = t.input.read_query_answer(cpr_pattern, 2)

  local width = 1 -- default to 1 if detection fails
  if responses and #responses == 2 then
    local r1 = tonumber(responses[1][1])
    local c1 = tonumber(responses[1][2])
    local r2 = tonumber(responses[2][1])
    local c2 = tonumber(responses[2][2])
    if r1 and c1 and r2 and c2 and r1 == r2 then
      local w = c2 - c1
      if w == 1 or w == 2 then
        width = w
      end
    end
    if r1 and c1 then
      -- erase the test character we wrote
      local restore = t.cursor.position.set_seq(r1, c1)
      t.output.write(restore .. string.rep(" ", width) .. restore)
    end
  end

  t.text.stack.pop()

  M.set_ambiguous_width(width)
  return width
end



--- Returns the current width used for ambiguous-width characters.
-- @treturn number 1 or 2
function M.get_ambiguous_width()
  return ambiguous_width
end



--- Sets the width used for ambiguous-width characters.
-- @tparam number n 1 or 2
function M.set_ambiguous_width(n)
  if n ~= 1 and n ~= 2 then
    error("ambiguous width must be 1 or 2", 2)
  end
  ambiguous_width = n
end



--- Returns the width of a character in columns.
-- Calculates character width, using the configured ambiguous width for ambiguous characters.
-- @tparam string|number char the character (string or codepoint) to check
-- @treturn number the width of the first character in columns
function M.utf8cwidth(char)
  if type(char) == "string" then
    char = utf8.codepoint(char)
  elseif type(char) ~= "number" then
    error("expected string or number, got " .. type(char), 2)
  end
  return sys_utf8cwidth(char, ambiguous_width)
end



--- Returns the width of a string in columns.
-- Calculates string width, using the configured ambiguous width for ambiguous characters.
-- @tparam string str the string to check
-- @treturn number the width of the string in columns
function M.utf8swidth(str)
  local w = 0
  for pos, cp in utf8.codes(str) do
    w = w + sys_utf8cwidth(cp, ambiguous_width)
  end
  return w
end



return M
