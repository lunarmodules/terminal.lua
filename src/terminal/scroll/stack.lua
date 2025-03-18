--- Terminal scroll stack module.
-- Manages a stack of scroll regions for terminal control.
-- @module terminal.scroll.stack
local M = {}
package.loaded["terminal.scroll.stack"] = M -- Register this module in package.loaded

local output = require("terminal.output")
local scroll = require("terminal.scroll")



local _scrollstack = {
  scroll.resets(), -- Use the function from scroll module
}



--- Retrieves the current scroll region sequence from the top of the stack.
-- @treturn string The ANSI sequence representing the current scroll region.
-- @within Sequences
function M.applys()
  return _scrollstack[#_scrollstack]
end


--- Applies the current scroll region by writing it to the terminal.
-- @treturn true Always returns true after applying.
function M.apply()
  output.write(M.applys())
  return true
end



--- Pushes a new scroll region onto the stack without applying it.
-- @tparam number top The top line number of the scroll region.
-- @tparam number bottom The bottom line number of the scroll region.
-- @treturn string The ANSI sequence representing the pushed scroll region.
-- @within Sequences
function M.pushs(top, bottom)
  _scrollstack[#_scrollstack + 1] = scroll.regions(top, bottom)
  return M.applys()
end



--- Pushes a new scroll region onto the stack and applies it by writing to the terminal.
-- @tparam number top The top line number of the scroll region.
-- @tparam number bottom The bottom line number of the scroll region.
-- @treturn true Always returns true after applying.
function M.push(top, bottom)
  output.write(M.pushs(top, bottom))
  return true
end


--- Pops the specified number of scroll regions from the stack without applying it.
-- @tparam number n The number of scroll regions to pop. Defaults to 1.
-- @treturn string The ANSI sequence representing the new top of the stack.
-- @within Sequences
function M.pops(n)
  local new_top = math.max(#_scrollstack - (n or 1), 1)
  for i = new_top + 1, #_scrollstack do
    _scrollstack[i] = nil
  end
  return M.applys()
end

--- Pops the specified number of scroll regions from the stack and applies the new top by writing to the terminal.
-- @tparam number n The number of scroll regions to pop. Defaults to 1.
-- @treturn true Always returns true after applying.
function M.pop(n)
  output.write(M.pops(n))
  return true
end


-- Only if we're testing export these internals (under a different name)
if _G._TEST then
  M.__scrollstack = _scrollstack
end



return M
