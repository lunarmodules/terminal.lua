--- Terminal cursor shape module.
-- Provides utilities for cursor shape handling in terminals.
-- @module terminal.cursor.shape

local M = {}
package.loaded["terminal.cursor.shape"] = M -- Register the module early to avoid circular dependencies

local output = require("terminal.output")
local utils = require("terminal.utils")



local shape_reset = "\27[0 q"
local _shapestack = {
  shape_reset
}




--=============================================================================
-- cursor shapes
--=============================================================================


local shapes = utils.make_lookup("cursor shape", {
  block_blink     = "\27[1 q",
  block           = "\27[2 q",
  underline_blink = "\27[3 q",
  underline       = "\27[4 q",
  bar_blink       = "\27[5 q",
  bar             = "\27[6 q",
})



--- Returns the ansi sequence for a cursor shape without writing it to the terminal.
-- @tparam string shape the shape to get, one of the keys `"block"`,
-- `"block_blink"`, `"underline"`, `"underline_blink"`, `"bar"`, `"bar_blink"`
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.set_seq(shape)
  return shapes[shape]
end



--- Sets the cursor shape and writes it to the terminal.
-- @tparam string shape the shape to set, one of the keys `"block"`,
-- `"block_blink"`, `"underline"`, `"underline_blink"`, `"bar"`, `"bar_blink"`
-- @return true
function M.set(shape)
  output.write(M.set_seq(shape))
  return true
end



--- Re-applies the shape at the top of the stack (returns it, does not write it to the terminal).
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.apply_seq()
  return _shapestack[#_shapestack]
end



--- Re-applies the shape at the top of the stack, and writes it to the terminal.
-- @return true
function M.apply()
  output.write(M.apply_seq())
  return true
end



--- Pushes a cursor shape onto the stack (and returns it), without writing it to the terminal.
-- @tparam string s the shape to push, one of the keys `"block"`,
-- `"block_blink"`, `"underline"`, `"underline_blink"`, `"bar"`, `"bar_blink"`
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.push_seq(s)
  _shapestack[#_shapestack + 1] = M.set_seq(s)
  return M.apply_seq()
end



--- Pushes a cursor shape onto the stack, and writes it to the terminal.
-- @tparam string s the shape to push, one of the keys `"block"`,
-- `"block_blink"`, `"underline"`, `"underline_blink"`, `"bar"`, `"bar_blink"`
-- @return true
function M.push(s)
  output.write(M.push_seq(s))
  return true
end



--- Pops `n` cursor shape(s) off the stack (and returns the last one), without writing it to the terminal.
-- @tparam[opt=1] number n number of shapes to pop
-- @treturn string ansi sequence to write to the terminal
-- @within Sequences
function M.pop_seq(n)
  local new_last = math.max(#_shapestack - (n or 1), 1)
  for i = new_last + 1, #_shapestack do
    _shapestack[i] = nil
  end
  return M.apply_seq()
end



--- Pops `n` cursor shape(s) off the stack, and writes the last one to the terminal.
-- @tparam[opt=1] number n number of shapes to pop
-- @return true
function M.pop(n)
  output.write(M.pop_seq(n))
  return true
end



return M
