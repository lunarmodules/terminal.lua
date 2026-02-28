--- Module for character and string display width in terminal columns.
-- Width detection is fully delegated to LuaSystem (>= 0.7). Ambiguous-width characters
-- are treated with a fixed width of 1; no runtime probing or terminal queries are performed.
-- The former `test()` and `test_write()` APIs have been removed.
--
-- Use `utf8cwidth` for a single character and `utf8swidth` for a string.
-- @module terminal.text.width

local M = {}
package.loaded["terminal.text.width"] = M -- Register the module early to avoid circular dependencies

local sys = require "system"
local sys_utf8cwidth = sys.utf8cwidth
local utf8 = require("utf8") -- explicit lua-utf8 library call, for <= Lua 5.3 compatibility


local AMBIGUOUS_WIDTH = 1



--- Returns the width of a character in columns, matches `system.utf8cwidth` signature.
-- @tparam string|number char the character (string or codepoint) to check
-- @treturn number the width of the first character in columns
function M.utf8cwidth(char)
  if type(char) == "string" then
    char = utf8.codepoint(char)
  elseif type(char) ~= "number" then
    error("expected string or number, got " .. type(char), 2)
  end
  return sys_utf8cwidth(char, AMBIGUOUS_WIDTH)
end



--- Returns the width of a string in columns, matches `system.utf8swidth` signature.
-- @tparam string str the string to check
-- @treturn number the width of the string in columns
function M.utf8swidth(str)
  local w = 0
  for pos, cp in utf8.codes(str) do
    w = w + sys_utf8cwidth(cp, AMBIGUOUS_WIDTH)
  end
  return w
end


return M
