--- Terminal text module.
-- Provides utilities to set text attributes in terminals.
-- @module terminal.text
local M = {}
package.loaded["terminal.text"] = M -- Register the module early to avoid circular dependencies

M.color = require("terminal.text.color")
M.stack = require("terminal.text.stack")

local output = require("terminal.output")
local utils = require("terminal.utils")
local color = M.color


local underline_on = "\27[4m"
local underline_off = "\27[24m"
local blink_on = "\27[5m"
local blink_off = "\27[25m"
local reverse_on = "\27[7m"
local reverse_off = "\27[27m"
local attribute_reset = "\27[0m"



--- Creates an ansi sequence to (un)set the underline attribute without writing it to the terminal.
-- @tparam[opt=true] boolean on whether to set underline
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.underlines(on)
  return on == false and underline_off or underline_on
end



--- (Un)sets the underline attribute and writes it to the terminal.
-- @tparam[opt=true] boolean on whether to set underline
-- @return true
function M.underline(on)
  output.write(M.underlines(on))
  return true
end



--- Creates an ansi sequence to (un)set the blink attribute without writing it to the terminal.
-- @tparam[opt=true] boolean on whether to set blink
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.blinks(on)
  return on == false and blink_off or blink_on
end



--- (Un)sets the blink attribute and writes it to the terminal.
-- @tparam[opt=true] boolean on whether to set blink
-- @return true
function M.blink(on)
  output.write(M.blinks(on))
  return true
end



--- Creates an ansi sequence to (un)set the reverse attribute without writing it to the terminal.
-- @tparam[opt=true] boolean on whether to set reverse
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.reverses(on)
  return on == false and reverse_off or reverse_on
end



--- (Un)sets the reverse attribute and writes it to the terminal.
-- @tparam[opt=true] boolean on whether to set reverse
-- @return true
function M.reverse(on)
  output.write(M.reverses(on))
  return true
end



-- lookup brightness levels
local _brightness = utils.make_lookup("brightness setting", {
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
-- @within Sequences
function M.brightnesss(brightness)
  return _brightness_sequence[_brightness[brightness]]
end



--- Sets the brightness and writes it to the terminal.
-- @tparam string|integer brightness the brightness to set
-- @return true
function M.brightness(brightness)
  output.write(M.brightnesss(brightness))
  return true
end



-- ansi sequences to apply for each brightness level, if done AFTER an attribute reset
local _brightness_sequence_after_reset = {
  -- 0 = invisible
  [0] = "\027[8m",
  -- 1 = dim
  [1] = "\027[2m",
  -- 2 = normal (no additional attributes needed after reset)
  [2] = "",
  -- 3 = bright/bold
  [3] = "\027[1m",
}



function M._newattr(attr)
  local last = M.stack._colorstack[#M.stack._colorstack]
  local fg_color = attr.fg or attr.fg_r
  local bg_color = attr.bg or attr.bg_r
  local new = {
    fg         = fg_color        == nil and last.fg         or color.fores(fg_color, attr.fg_g, attr.fg_b),
    bg         = bg_color        == nil and last.bg         or color.backs(bg_color, attr.bg_g, attr.bg_b),
    brightness = attr.brightness == nil and last.brightness or _brightness[attr.brightness],
    underline  = attr.underline  == nil and last.underline  or (not not attr.underline),
    blink      = attr.blink      == nil and last.blink      or (not not attr.blink),
    reverse    = attr.reverse    == nil and last.reverse    or (not not attr.reverse),
  }
  new.ansi = attribute_reset .. new.fg .. new.bg ..
    _brightness_sequence_after_reset[new.brightness] ..
    (new.underline and M.underlines(true) or "") ..
    (new.blink and M.blinks(true) or "") ..
    (new.reverse and M.reverses(true) or "")
  return new
end



--- Creates an ansi sequence to set all text attributes/colors without writing it to the terminal.
-- Only set what you change. Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, with keys:
-- @tparam[opt] string|integer attr.fg the foreground color to set. Base color (string), or extended color (number). Takes precedence of `fg_r`, `fg_g`, `fg_b`.
-- @tparam[opt] integer attr.fg_r the red value of the foreground color to set.
-- @tparam[opt] integer attr.fg_g the green value of the foreground color to set.
-- @tparam[opt] integer attr.fg_b the blue value of the foreground color to set.
-- @tparam[opt] string|integer attr.bg the background color to set. Base color (string), or extended color (number). Takes precedence of `bg_r`, `bg_g`, `bg_b`.
-- @tparam[opt] integer attr.bg_r the red value of the background color to set.
-- @tparam[opt] integer attr.bg_g the green value of the background color to set.
-- @tparam[opt] integer attr.bg_b the blue value of the background color to set.
-- @tparam[opt] string|number attr.brightness the brightness level to set
-- @tparam[opt] boolean attr.underline whether to set underline
-- @tparam[opt] boolean attr.blink whether to set blink
-- @tparam[opt] boolean attr.reverse whether to set reverse
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
-- @usage
-- local str = terminal.text.attrs({
--   fg = "red",
--   bg = "black",
--   brightness = 3,
--   underline = true,
--   blink = false,
--   reverse = false
-- })
function M.attrs(attr)
  local new = M._newattr(attr)
  return new.ansi
end



--- Sets all text attributes/colors and writes it to the terminal.
-- Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, see `attrs` for details.
-- @return true
-- @usage
-- terminal.text.attr({
--   fg = "red",
--   bg = "black",
--   brightness = 3,
--   underline = true,
--   blink = false,
--   reverse = false
-- })
function M.attr(attr)
  output.write(M.textsets(attr))
  return true
end



return M
