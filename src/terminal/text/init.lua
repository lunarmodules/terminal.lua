--- Terminal text module.
-- Provides utilities to set text attributes in terminals.
-- @module terminal.text
local M = {}
package.loaded["terminal.text"] = M -- Register the module early to avoid circular dependencies

M.color = require("terminal.text.color")


local output = require("terminal.output")
local utils = require("terminal.utils")


local underline_on = "\27[4m"
local underline_off = "\27[24m"
local blink_on = "\27[5m"
local blink_off = "\27[25m"
local reverse_on = "\27[7m"
local reverse_off = "\27[27m"



--- Creates an ansi sequence to (un)set the underline attribute without writing it to the terminal.
-- @tparam[opt=true] boolean on whether to set underline
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.underlines(on)
  return on == false and underline_off or underline_on
end



--- (Un)sets the underline attribute and writes it to the terminal.
-- @tparam[opt=true] boolean on whether to set underline
-- @return true
-- @within textcolor
function M.underline(on)
  output.write(M.underlines(on))
  return true
end



--- Creates an ansi sequence to (un)set the blink attribute without writing it to the terminal.
-- @tparam[opt=true] boolean on whether to set blink
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.blinks(on)
  return on == false and blink_off or blink_on
end



--- (Un)sets the blink attribute and writes it to the terminal.
-- @tparam[opt=true] boolean on whether to set blink
-- @return true
-- @within textcolor
function M.blink(on)
  output.write(M.blinks(on))
  return true
end



--- Creates an ansi sequence to (un)set the reverse attribute without writing it to the terminal.
-- @tparam[opt=true] boolean on whether to set reverse
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.reverses(on)
  return on == false and reverse_off or reverse_on
end



--- (Un)sets the reverse attribute and writes it to the terminal.
-- @tparam[opt=true] boolean on whether to set reverse
-- @return true
-- @within textcolor
function M.reverse(on)
  output.write(M.reverses(on))
  return true
end



do
  -- lookup brightness levels
  M._brightness = utils.make_lookup("brightness setting", {
    off = 0,
    low = 1,
    normal = 2,
    high = 3,
    [0] = 0,
    [1] = 1,
    [2] = 2,
    [3] = 3,
    -- common terminal codes
    invisible = 0,
    dim = 1,
    bright = 3,
    bold = 3,
  })


  -- ansi sequences to apply for each brightness level (always works, does not need a reset)
  -- (a reset would also have an effect on underline, blink, and reverse)
  local _brightness_sequence = utils.make_lookup("brightness level", {
    -- 0 = remove bright and dim, apply invisible
    [0] = "\027[22m\027[8m",
    -- 1 = remove bold/dim, remove invisible, set dim
    [1] = "\027[22m\027[28m\027[2m",
    -- 2 = normal, remove dim, bright, and invisible
    [2] = "\027[22m\027[28m",
    -- 3 = remove bold/dim, remove invisible, set bright/bold
    [3] = "\027[22m\027[28m\027[1m",
  })



  --- Creates an ansi sequence to set the brightness without writing it to the terminal.
  -- `brightness` can be one of the following:
  --
  -- - `0`, `"off"`, or `"invisble"` for invisible
  -- - `1`, `"low"`, or `"dim"` for dim
  -- - `2`, `"normal"` for normal
  -- - `3`, `"high"`, `"bright"`, or `"bold"` for bright
  --
  -- @tparam string|integer brightness the brightness to set
  -- @treturn string ansi sequence to write to the terminal
  -- @within textcolor
  function M.brightnesss(brightness)
    return _brightness_sequence[M._brightness[brightness]]
  end
end



--- Sets the brightness and writes it to the terminal.
-- @tparam string|integer brightness the brightness to set
-- @return true
-- @within textcolor
function M.brightness(brightness)
  output.write(M.brightnesss(brightness))
  return true
end



return M
