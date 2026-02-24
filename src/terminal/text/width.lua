--- Character display width helpers.
-- Uses LuaSystem width calculations with an optional calibrated
-- ambiguous-width value for terminal-specific behavior.
-- @module terminal.text.width

local M = {}
package.loaded["terminal.text.width"] = M -- Register the module early to avoid circular dependencies

local t = require "terminal"
local sys = require "system"

local sys_utf8cwidth = sys.utf8cwidth
local sys_utf8swidth = sys.utf8swidth
local utf8 = require("utf8") -- explicit lua-utf8 library call, for <= Lua 5.3 compatibility
local ambiguous_char = "·"
local ambiguous_codepoint = utf8.codepoint(ambiguous_char)

M.ambiguous_width = nil


local function detect_ambiguous_width()
  local row, col = t.cursor.position.get()
  if not row then
    return nil, col
  end
  local setpos = t.cursor.position.set_seq(row, col)
  local query = ambiguous_char .. t.cursor.position.query_seq() .. setpos

  t.text.stack.push({ brightness = 0 })
  local result, err = t.input.query(query, "^\27%[(%d+);(%d+)R$")
  t.text.stack.pop()

  if not result then
    return nil, err
  end

  local measured_col = tonumber(result[2])
  if not measured_col then
    return nil, "invalid cursor query response"
  end

  local width = measured_col - col
  if width < 0 then
    local _, cols = t.size()
    width = width + cols
  end

  if width ~= 1 and width ~= 2 then
    return nil, "invalid ambiguous width: " .. tostring(width)
  end

  return width
end


--- Initializes the module-wide ambiguous-width value.
-- If terminal probing is unavailable, this falls back to LuaSystem defaults.
-- @tparam[opt=false] boolean force_probe force terminal probing when initialized
-- @treturn number ambiguous width (1 or 2)
function M.initialize(force_probe)
  if M.ambiguous_width and not force_probe then
    return M.ambiguous_width
  end

  if t.ready and t.ready() then
    local width = detect_ambiguous_width()
    if width then
      M.ambiguous_width = width
      return width
    end
    if M.ambiguous_width then
      return M.ambiguous_width
    end
  end

  M.ambiguous_width = sys_utf8cwidth(ambiguous_codepoint)
  return M.ambiguous_width
end

--- Returns the width of a character in columns, matches `system.utf8cwidth` signature.
-- @tparam string|number char the character (string or codepoint) to check
-- @treturn number the width of the first character in columns
function M.utf8cwidth(char)
  if type(char) == "string" then
    char = utf8.codepoint(char)
  elseif type(char) ~= "number" then
    error("expected string or number, got " .. type(char), 2)
  end
  return sys_utf8cwidth(char, M.ambiguous_width)
end


--- Returns the width of a string in columns, matches `system.utf8swidth` signature.
-- @tparam string str the string to check
-- @treturn number the width of the string in columns
function M.utf8swidth(str)
  return sys_utf8swidth(str, M.ambiguous_width)
end


--- Returns the width of a string.
-- @tparam string str the string of characters to test
-- @treturn number the width of the string in columns
-- @within Testing
function M.test(str)
  M.initialize()
  return M.utf8swidth(str)
end


--- Writes a string and returns its width.
-- @tparam string str the string of characters to write and test
-- @treturn number the width of the string in columns
-- @within Testing
function M.test_write(str)
  M.initialize()
  t.output.write(str)
  return M.utf8swidth(str)
end

return M
