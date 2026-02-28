--- Module for character and string display width in terminal columns.
-- Delegates to LuaSystem (>= 0.7). Ambiguous-width characters use a configurable width
-- (default 1); no runtime probing or terminal queries are performed.
--
-- Use `utf8cwidth` for a single character and `utf8swidth` for a string.
-- Use `set_ambiguous_width` to set the width used for ambiguous-width characters (1 or 2).
-- @module terminal.text.width

local M = {}
package.loaded["terminal.text.width"] = M -- Register the module early to avoid circular dependencies

local sys = require "system"
local sys_utf8cwidth = sys.utf8cwidth
local utf8 = require("utf8") -- explicit lua-utf8 library call, for <= Lua 5.3 compatibility


local ambiguous_width = 1



--- Sets the width used for ambiguous-width characters (e.g. some CJK).
-- @tparam number n 1 or 2
function M.set_ambiguous_width(n)
  if n ~= 1 and n ~= 2 then
    error("ambiguous width must be 1 or 2", 2)
  end
  ambiguous_width = n
end



--- Returns the width of a character in columns. Delegates to LuaSystem; ambiguous width is configurable (default 1).
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



--- Returns the width of a string in columns. Delegates to LuaSystem; ambiguous width is configurable (default 1).
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
