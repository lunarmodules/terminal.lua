--- Module to check and validate character display widths.
-- Not all characters are displayed with the same width on the terminal.
-- The Unicode standard defines the width of many characters, but not all.
-- Especially the ['ambiguous width'](https://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt)
-- characters can be displayed with different
-- widths especially when used with East Asian languages.
--
-- This module delegates width calculation to LuaSystem (>= 0.7.0), which provides
-- `system.utf8cwidth(char, ambiguous_width)` and `system.utf8swidth(str, ambiguous_width)`.
-- A single ambiguous-width character is probed at initialization (e.g. via
-- `terminal.preload_widths`) and the result is stored globally; all width calls
-- use that value for ambiguous characters.
--
-- To ensure the terminal's ambiguous width is detected, call `terminal.preload_widths()`
-- after `terminal.initialize()`. Width functions are safe before that: they use
-- a default ambiguous width of 1.
-- @module terminal.text.width

local M = {}
package.loaded["terminal.text.width"] = M -- Register the module early to avoid circular dependencies

local t = require "terminal"
local sys = require "system"
local utf8 = require("utf8") -- explicit lua-utf8 library call, for <= Lua 5.3 compatibility


--- Stored width for ambiguous-width characters (1 or 2). Set by `detect_ambiguous_width`.
-- When nil, width functions use 1 (safe default). Do not set directly; use
-- `detect_ambiguous_width` or `set_ambiguous_width`.
M.ambiguous_width = nil


local function ambiguous_width()
  return M.ambiguous_width or 1
end


--- Returns the width of a character in columns, matches `system.utf8cwidth` signature.
-- Delegates to `system.utf8cwidth(char, ambiguous_width)`.
-- @tparam string|number char the character (string or codepoint) to check
-- @treturn number the width of the first character in columns
function M.utf8cwidth(char)
  if type(char) == "string" then
    char = utf8.codepoint(char)
  elseif type(char) ~= "number" then
    error("expected string or number, got " .. type(char), 2)
  end
  return sys.utf8cwidth(char, ambiguous_width())
end



--- Returns the width of a string in columns, matches `system.utf8swidth` signature.
-- Delegates to `system.utf8swidth(str, ambiguous_width)`.
-- @tparam string str the string to check
-- @treturn number the width of the string in columns
function M.utf8swidth(str)
  return sys.utf8swidth(str, ambiguous_width())
end



--- Sets the ambiguous character width used for all width calculations.
-- Normally called by `detect_ambiguous_width`; exposed for tests or overrides.
-- @tparam number aw 1 or 2
-- @within Initialization
function M.set_ambiguous_width(aw)
  assert(aw == 1 or aw == 2, "ambiguous_width must be 1 or 2, got " .. tostring(aw))
  M.ambiguous_width = aw
end



--- Detects the terminal's width for ambiguous-width characters by probing one character.
-- Uses cursor-position report (CPR); only runs when terminal is initialized and
-- stdout/stderr is a TTY. Does not write to the terminal otherwise. Idempotent:
-- if `ambiguous_width` is already set, returns immediately.
-- @treturn[1] number the detected width (1 or 2), or 1 if detection was skipped
-- @treturn[2] nil
-- @treturn[2] string error message only when probe was attempted and failed
-- @within Initialization
function M.detect_ambiguous_width()
  if M.ambiguous_width ~= nil then
    return M.ambiguous_width
  end

  if not t.ready() then
    M.ambiguous_width = 1
    return 1
  end

  -- Probe only when output is a TTY to avoid unnecessary write
  if not sys.isatty(t.output.get_stream()) then
    M.ambiguous_width = 1
    return 1
  end

  -- Probe one ambiguous character (U+00B7 MIDDLE DOT)
  local probe_char = utf8.char(0x00B7)
  t.text.stack.push({ brightness = 0 })

  local r, c = t.cursor.position.get()
  if not r or not c then
    t.text.stack.pop()
    M.ambiguous_width = 1
    return 1
  end

  local setpos = t.cursor.position.set_seq(r, c)
  local getpos = t.cursor.position.query_seq()
  t.output.write(probe_char .. getpos .. setpos)
  t.output.flush()

  local positions = t.input.read_query_answer("^\27%[(%d+);(%d+)R$", 1)
  t.text.stack.pop()

  if not positions or #positions < 1 then
    M.ambiguous_width = 1
    return 1
  end

  local _, cols = t.size()
  local col_after = tonumber(positions[1][2])
  local w = col_after - c
  if w < 0 then
    w = w + (cols or 80)
  end
  M.ambiguous_width = (w == 2) and 2 or 1
  return M.ambiguous_width
end



--- Returns the width of the string in columns.
-- Ensures ambiguous width has been detected (if terminal is ready and TTY), then
-- returns the same as `utf8swidth(str)`. Kept for API compatibility; no longer
-- probes or caches per-character widths.
-- @tparam string str the string to measure
-- @treturn[1] number width in columns of the string
-- @treturn[2] nil
-- @treturn[2] string error message (only if detection was run and failed)
-- @within Testing
function M.test(str)
  M.detect_ambiguous_width()
  return M.utf8swidth(str or "")
end



--- Writes the string to the terminal and returns its width in columns.
-- Ensures ambiguous width has been detected, writes the string, then returns
-- `utf8swidth(str)`. Kept for API compatibility; no longer probes per-character.
-- @tparam string str the string to write and measure
-- @treturn number the width of the string in columns
-- @within Testing
function M.test_write(str)
  M.detect_ambiguous_width()
  t.output.write(str or "")
  return M.utf8swidth(str or "")
end


return M
