-- Module for setting a stack of text colors and attributes
-- Allows you to push and pop, color and text attributes.
-- @usage
-- local colorstack = require("terminal.color.stack")

-- @module terminal.color.stack

local M = {}
package.loaded["terminal.color.stack"]
local output = "terminal.output"

local _colorstack = {
    default_colors,
  }

  --=============================================================================
-- text_stack: colors & attributes
--=============================================================================
-- Text colors and attributes stack.
-- Stack for managing the text color and attributes.
-- @section textcolor_stack


local function newtext(attr)
    local last = _colorstack[#_colorstack]
    local fg_color = attr.fg or attr.fg_r
    local bg_color = attr.bg or attr.bg_r
    local new = {
      fg         = fg_color        == nil and last.fg         or colorcode(fg_color, attr.fg_g, attr.fg_b, true),
      bg         = bg_color        == nil and last.bg         or colorcode(bg_color, attr.bg_g, attr.bg_b, false),
      brightness = attr.brightness == nil and last.brightness or _brightness[attr.brightness],
      underline  = attr.underline  == nil and last.underline  or (not not attr.underline),
      blink      = attr.blink      == nil and last.blink      or (not not attr.blink),
      reverse    = attr.reverse    == nil and last.reverse    or (not not attr.reverse),
    }
    new.ansi = attribute_reset .. new.fg .. new.bg ..
      _brightness_sequence_after_reset[new.brightness] ..
      (new.underline and underline_on or "") ..
      (new.blink and blink_on or "") ..
      (new.reverse and reverse_on or "")
    -- print("newtext:", (new.ansi:gsub("\27", "\\27")))
    return new
  end
  
  --- Creates an ansi sequence to set the text attributes without writing it to the terminal.
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
  function M.textsets(attr)
    local new = newtext(attr)
    return new.ansi
  end
  
  --- Sets the text attributes and writes it to the terminal.
  -- Every element omitted in the `attr` table will be taken from the current top of the stack.
  -- @tparam table attr the attributes to set, see `textsets` for details.
  -- @return true
  function M.textset(attr)
    output.write(newtext(attr).ansi)
    return true
  end
  
  --- Pushes the current attributes onto the stack, and returns an ansi sequence to set the new attributes without writing it to the terminal.
  -- Every element omitted in the `attr` table will be taken from the current top of the stack.
  -- @tparam table attr the attributes to set, see `textsets` for details.
  -- @treturn string ansi sequence to write to the terminal
  function M.textpushs(attr)
    local new = newtext(attr)
    _colorstack[#_colorstack + 1] = new
    return new.ansi
  end
  
  --- Pushes the current attributes onto the stack, and writes an ansi sequence to set the new attributes to the terminal.
  -- Every element omitted in the `attr` table will be taken from the current top of the stack.
  -- @tparam table attr the attributes to set, see `textsets` for details.
  -- @return true
  function M.textpush(attr)
    output.write(M.textpushs(attr))
    return true
  end
  
  --- Pops n attributes off the stack (and returns the last one), without writing it to the terminal.
  -- @tparam[opt=1] number n number of attributes to pop
  -- @treturn string ansi sequence to write to the terminal
  function M.textpops(n)
    n = n or 1
    local newtop = math.max(#_colorstack - n, 1)
    for i = newtop + 1, #_colorstack do
      _colorstack[i] = nil
    end
    return _colorstack[#_colorstack].ansi
  end
  
  --- Pops n attributes off the stack, and writes the last one to the terminal.
  -- @tparam[opt=1] number n number of attributes to pop
  -- @return true
  function M.textpop(n)
    output.write(M.textpops(n))
    return true
  end
  
  --- Re-applies the current attributes (returns it, does not write it to the terminal).
  -- @treturn string ansi sequence to write to the terminal
  function M.textapplys()
    return _colorstack[#_colorstack].ansi
  end
  
  --- Re-applies the current attributes, and writes it to the terminal.
  -- @return true
  function M.textapply()
    output.write(_colorstack[#_colorstack].ansi)
    return true
  end
  
  return M