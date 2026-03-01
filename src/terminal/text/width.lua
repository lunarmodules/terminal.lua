--- Module for character and string display width in terminal columns.
-- Delegates to LuaSystem (>= 0.7). Ambiguous-width characters use a configurable width
-- (default 1). Optionally, ambiguous width is detected once during terminal initialization.
--
-- Use `utf8cwidth` for a single character and `utf8swidth` for a string.
-- Use `set_ambiguous_width` / `get_ambiguous_width` to control the width used for ambiguous-width characters (1 or 2).
-- @module terminal.text.width

local M = {}
package.loaded["terminal.text.width"] = M -- Register the module early to avoid circular dependencies

local sys = require "system"
local sys_utf8cwidth = sys.utf8cwidth
local utf8 = require("utf8") -- explicit lua-utf8 library call, for <= Lua 5.3 compatibility


local ambiguous_width = 1


local function detect_ambiguous_width(filehandle)
  if not sys.isatty(filehandle) then
    return 1
  end

  local output = require("terminal.output")
  local input = require("terminal.input")
  local text = require("terminal.text")
  local cursor_pos = require("terminal.cursor.position")

  local probe_char = utf8.char(0x00A1)
  local cpr = cursor_pos.query_seq()
  local invisible_on = text.brightness_seq(0)
  local invisible_off = text.brightness_seq(2)
  local cpr_pattern = "^\27%[(%d+);(%d+)R$"

  local width = 1

  input.preread()
  output.write(invisible_on .. cpr .. probe_char .. cpr)
  output.flush()

  pcall(function()
    local responses = input.read_query_answer(cpr_pattern, 2)

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
        local restore = cursor_pos.set_seq(r1, c1)
        output.write(restore .. string.rep(" ", width) .. restore)
      end
    end
  end)

  output.write(invisible_off)
  output.flush()

  return width
end



--- Runs one-time ambiguous-width detection and sets the module value. Called from terminal.initialize.
-- @tparam file filehandle output stream (e.g. opts.filehandle or io.stderr)
function M.detect_and_set_ambiguous_width(filehandle)
  ambiguous_width = detect_ambiguous_width(filehandle or io.stderr)
end



--- Returns the current width used for ambiguous-width characters.
-- @treturn number 1 or 2
function M.get_ambiguous_width()
  return ambiguous_width
end



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
