-- Terminal Scroll Stack Module.
-- Manages a stack of scroll regions for terminal control.
-- @module scroll.stack
local M = {}
local output = require("terminal.output")

-- Use `package.loaded` to avoid requiring `scroll` directly, preventing circular dependency
local scroll = package.loaded["terminal.scroll"]

-- Register this module in package.loaded
package.loaded["terminal.scroll.stack"] = M

local _scrollstack = {
  scroll.scroll_reset(), -- Use the function from scroll module
}

--- Retrieves the current scroll region sequence from the top of the stack.
-- @treturn string The ANSI sequence representing the current scroll region.
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
function M.pushs(top, bottom)
  _scrollstack[#_scrollstack + 1] = scroll.scroll_regions(top, bottom)
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
function M.pops(n)
  n = n or 1
  for _ = 1, n do
    if #_scrollstack > 1 then
      table.remove(_scrollstack) -- Only remove if not at base level
    end
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

return M
