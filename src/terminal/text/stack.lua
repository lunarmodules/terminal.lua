--- Terminal text-attribute stack module.
-- Manages a stack of text-attributes for terminal control.
-- @module terminal.scroll.stack
local M = {}
package.loaded["terminal.text.stack"] = M -- Register this module in package.loaded

local output = require("terminal.output")
local text = require("terminal.text")



local fg_color_reset = "\27[39m"
local bg_color_reset = "\27[49m"
local attribute_reset = "\27[0m"


local default_colors = {
  fg = fg_color_reset, -- reset fg
  bg = bg_color_reset, -- reset bg
  brightness = 2, -- normal
  underline = false,
  blink = false,
  reverse = false,
  ansi = fg_color_reset .. bg_color_reset .. attribute_reset,
}


local _colorstack = {
  default_colors,
}
M._colorstack = _colorstack



--- Pushes the given attributes/colors onto the stack, and returns an ansi sequence to set the new
-- attributes without writing it to the terminal.
-- Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, see `text.attrs` for details.
-- @treturn string ansi sequence to write to the terminal
function M.pushs(attr)
  local new = text._newattr(attr)
  _colorstack[#_colorstack + 1] = new
  return new.ansi
end



--- Pushes the given attributes/colors onto the stack, and writes an ansi sequence to set the new
-- attributes to the terminal.
-- Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, see `text.attrs` for details.
-- @return true
function M.push(attr)
  output.write(M.pushs(attr))
  return true
end



--- Pops n attributes/colors off the stack (and returns the last one), without writing it to the terminal.
-- @tparam[opt=1] number n number of attributes to pop
-- @treturn string ansi sequence to write to the terminal
function M.pops(n)
  n = n or 1
  local newtop = math.max(#_colorstack - n, 1)
  for i = newtop + 1, #_colorstack do
    _colorstack[i] = nil
  end
  return _colorstack[#_colorstack].ansi
end



--- Pops n attributes/colors off the stack, and writes the last one to the terminal.
-- @tparam[opt=1] number n number of attributes to pop
-- @return true
function M.pop(n)
  output.write(M.pops(n))
  return true
end



--- Re-applies the current attributes/colors (at the top of the stack),
-- returns the sequence without writing to the terminal.
-- @treturn string ansi sequence to write to the terminal
function M.applys()
  return _colorstack[#_colorstack].ansi
end



--- Re-applies the current attributes/colors (at the top of the stack), and writes it to the terminal.
-- @return true
function M.apply()
  output.write(_colorstack[#_colorstack].ansi)
  return true
end



return M
