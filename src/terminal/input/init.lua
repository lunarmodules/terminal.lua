--- Module for getting keyboard input.
-- Also enables querying the terminal. When implementing any
-- other queries, check out `preread` and `read_query_answer` documentation.
--
-- *Example:*
--     local terminal = require "terminal"
--     terminal.initialize()
--
--     local char, typ, sequence = terminal.input.readansi(1)
-- @module terminal.input

local sys = require "system"

local M = {}
package.loaded["terminal.input"] = M -- Register the module early to avoid circular dependencies
M.keymap = require("terminal.input.keymap")
local terminal = require("terminal")
local output = require("terminal.output")



local kbbuffer = {}  -- buffer for keyboard input, what was pre-read
local kbstart = 0 -- index of the first element in the buffer
local kbend = 0 -- index of the last element in the buffer



local pack, unpack do
  -- nil-safe versions of pack/unpack
  local oldunpack = _G.unpack or table.unpack -- luacheck: ignore
  pack = function(...) return { n = select("#", ...), ... } end
  unpack = function(t, i, j) return oldunpack(t, i or 1, j or t.n or #t) end
end



--- The original readansi function from LuaSystem.
-- @function sys_readansi
M.sys_readansi = sys.readansi



--- Same as [`sys.readansi`](https://lunarmodules.github.io/luasystem/modules/system.html#readansi),
-- but works with the internal buffer required by `terminal.lua`.
-- This function will read from the internal buffer first, before calling `sys.readansi`. This is
-- required because querying the terminal (e.g. getting cursor position) might read data
-- from the keyboard buffer, which would be lost if not buffered. Hence this function
-- must be used instead of `sys.readansi`, to ensure the previously read buffer is
-- consumed first.
-- @tparam number timeout the timeout in seconds
-- @tparam[opt] function fsleep the sleep function to use (default: the sleep function
-- set by `initialize`)
-- @see terminal.input.keymap
-- @usage
-- local t = require "terminal"
-- local key_names = t.input.keymap.default_key_map
-- local keys = t.input.keymap.default_keys
--
-- -- read a key, and look up its name
-- local rawkey, keytype = t.input.readansi(math.huge)
-- local keyname = key_names[rawkey] -- note: not every key has a name
--
-- -- use the 'keys' table to check for key-names to prevent
-- -- having to use magic strings
-- if keyname == keys.escape then
--   t.output.print("Escape key pressed")
-- elseif keyname == keys.up then
--   t.output.print("Up key pressed")
-- elseif keyname == keys.down then
--   t.output.print("Down key pressed")
-- elseif keyname == keys.left then
--   t.output.print("Left key pressed")
-- elseif keyname == keys.right then
--   t.output.print("Right key pressed")
-- else
--   -- check on key-type; ctrl/ansi/char
--   if keytype == "ctrl" then
--     t.output.print("Control key pressed: " .. tostring(keyname))
--   elseif keytype == "ansi" then
--     t.output.print("ANSI key pressed: " .. tostring(keyname))
--   elseif keytype == "char" then
--     t.output.print("Character key pressed: " .. tostring(rawkey))  -- use rawkey here, not keyname
--   else
--     error("this cannot happen! keytype: " .. tostring(keytype))
--   end
-- end
function M.readansi(timeout, fsleep)
  if kbend == 0 then
    -- buffer is empty, so read from the terminal
    return M.sys_readansi(timeout, fsleep or terminal._asleep)
  end

  -- return buffered input
  kbstart = kbstart + 1
  local res = kbbuffer[kbstart]
  kbbuffer[kbstart] = nil
  if kbstart == kbend then
    kbstart = 0
    kbend = 0
  end
  return unpack(res)
end



--- Pushes input into the buffer.
-- The input will be appended to the current buffer contents. This means the data being pushed
-- ends up after the current buffer contents, but before the next data read from stdin.
-- The input parameters are the same as those returned by `readansi`.
-- @param seq the sequence of input
-- @param typ the type of input
-- @param part the partial of the input
-- @return true
-- @within Querying
function M.push_input(seq, typ, part)
  kbend = kbend + 1
  kbbuffer[kbend] = pack(seq, typ, part)
  return true
end



--- Preread `stdin` buffer into internal buffer.
-- This function will read from `stdin` and store the input in the internal buffer.
-- This is required because querying the terminal (e.g. getting cursor position) might
-- read data from the keyboard buffer, which would be lost if not buffered. Hence this
-- function should be called before querying the terminal.
--
-- Typical query flow;
--
-- 1. call `preread` to empty `stdin` buffer into internal buffer.
-- 2. query terminal by writing the required ANSI escape sequences.
-- 3. call `flush` to ensure the ANSI sequences are sent to the terminal.
-- 4. call `read_query_answer` to read the terminal responses.
--
-- @return true if successful, nil and an error message if reading failed
-- @within Querying
function M.preread()
  while true do
    local seq, typ, part = M.sys_readansi(0, terminal._bsleep)
    if seq == nil and typ == "timeout" then
      return true
    end
    M.push_input(seq, typ, part)
    if seq == nil then
      -- error reading keyboard
      return nil, "error reading keyboard: " .. typ
    end
  end
  -- unreachable
end



--- Reads the answer to a query from the terminal.
-- @tparam string answer_pattern a pattern that matches the expected ANSI response sequence, and captures the data needed.
-- @tparam[opt=1] number count the number of responses to read (in case multiple queries were sent)
-- @treturn[1] table an array with `count` entries. Each entry is another array with the captures from the answer pattern.
-- @treturn[2] nil on timeout or keyboard read error.
-- @treturn[2] string error message (e.g. `"timeout: no response from terminal"` or `"error reading keyboard: ..."`).
-- @within Querying
function M.read_query_answer(answer_pattern, count)
  count = count or 1
  -- read responses
  local result = {}
  while true do
    local seq, typ, part = M.sys_readansi(0.5, terminal._bsleep) -- 500ms timeout, max time for terminal to respond
    if seq == nil and typ == "timeout" then
      return nil, "timeout: no response from terminal"
    end
    if typ == "ansi" then
      local captures = { seq:match(answer_pattern) }
      if captures[1] then
        -- at least 1 element was captured by the pattern
        result[#result+1] = captures
        if #result >= count then
          break
        end
      else
        -- ignore other ansi sequences
        M.push_input(seq, typ, part)
      end
    else
      -- ignore other input
      M.push_input(seq, typ, part)
    end
    if seq == nil then
      -- error reading keyboard
      return nil, "error reading keyboard: " .. typ
    end
  end

  return result
end



--- Query the terminal.
-- This is a wrapper around `preread` and `read_query_answer`. It sends a single query and reads the answer
-- in one go. It is a convenience function for simple queries. It is limited to only a single query/answer pair.
-- @tparam string query the ANSI sequence to be written to query the terminal
-- @tparam string answer_pattern a pattern that matches the expected ANSI response sequence, and captures the data needed.
-- @treturn[1] table an array with the captures from the answer pattern.
-- @treturn[2] nil on timeout or keyboard read error (see `read_query_answer`).
-- @treturn[2] string error message.
-- @within Querying
function M.query(query, answer_pattern)
  M.preread()
  output.write(query)
  output.flush()

  local result, err = M.read_query_answer(answer_pattern, 1)
  if not result then
    return nil, err
  end

  return result[1]
end



return M
