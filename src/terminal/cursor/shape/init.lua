--- Terminal cursor shape module.
-- Provides utilities for cursor shape handling in terminals.
-- @module terminal.cursor.shape

local M = {}
package.loaded["terminal.cursor.shape"] = M -- Register the module early to avoid circular dependencies
M.stack = require "terminal.cursor.shape.stack"

local output = require("terminal.output")
local utils = require("terminal.utils")





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



return M
