--- Module for getting keyboard input.
-- Also enables querying the terminal for cursor position. When inmplementing any
-- other queries, check out `preread` documentation, and `read_cursor_pos` for
-- an example.
--
-- *Note:* This module will be available from the main `terminal` module, without
-- explicitly requiring it.
-- @usage
-- local terminal = require "terminal"
-- terminal.initialize()
--
-- local char, typ, sequence = terminal.input.readansi(1)
-- @module terminal.input

local sys = require "system"

local M = {}



local kbbuffer = {}  -- buffer for keyboard input, what was pre-read
local kbstart = 0 -- index of the first element in the buffer
local kbend = 0 -- index of the last element in the buffer
local asleep = sys.sleep -- default sleep function
local bsleep = sys.sleep -- sleep function that blocks



local pack, unpack do
  -- nil-safe versions of pack/unpack
  local oldunpack = _G.unpack or table.unpack -- luacheck: ignore
  pack = function(...) return { n = select("#", ...), ... } end
  unpack = function(t, i, j) return oldunpack(t, i or 1, j or t.n or #t) end
end



--- The original readansi function from LuaSystem.
-- @function sys_readansi
M.sys_readansi = sys.readansi



--- Set the default `sleep` function to use by `readansi`.
-- When using the library in a non-blocking environment, the `sleep` function must be
-- set to a function that will yield control to the event loop.
-- @tparam function fsleep the sleep function to use.
-- @return true
function M.set_sleep(fsleep)
  if type(fsleep) ~= "function" then
    error("sleep function must be a function", 2)
  end
  asleep = fsleep
  return true
end



--- Set the blocking `sleep` function used when no yielding is allowed.
-- @tparam function fsleep the sleep function to use.
-- @return true
function M.set_bsleep(fsleep)
  if type(fsleep) ~= "function" then
    error("sleep function must be a function", 2)
  end
  bsleep = fsleep
  return true
end



--- Same as `sys.readansi`, but works with the internal buffer required by `terminal.lua`.
-- This function will read from the internal buffer first, before calling `sys.readansi`. This is
-- required because querying the terminal (e.g. getting cursor position) might read data
-- from the keyboard buffer, which would be lost if not buffered. Hence this function
-- must be used instead of `sys.readansi`, to ensure the previously read buffer is
-- consumed first.
-- @tparam number timeout the timeout in seconds
-- @tparam[opt] function fsleep the sleep function to use (default: the sleep function
-- set by `initialize`)
function M.readansi(timeout, fsleep)
  if kbend == 0 then
    -- buffer is empty, so read from the terminal
    return M.sys_readansi(timeout, fsleep or asleep)
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
-- The input will be appended to the current buffer contents.
-- The input parameters are the same as those returned by `readansi`.
-- @param seq the sequence of input
-- @param typ the type of input
-- @param part the partial of the input
-- @return true
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
-- 4. call `readansi` to read the terminal response in a loop until the expected response
-- is received. Anything received that doesn't match the expected response should be
-- pushed into the internal buffer using `push_input`. (see `read_cursor_pos` for an
-- example)
--
-- *Note:* step 4, calling `readansi` in a loop, should be done while passing a blocking
-- sleep function to prevent yielding, and introducing potential race conditionas.
-- @return true if successful, nil and an error message if reading failed
function M.preread()
  while true do
    local seq, typ, part = M.sys_readansi(0, bsleep)
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



--- Read the requested number of cursor positions.
-- Ensure to request and flush this number of positions (by writing the query-cursor-position
-- ANSI sequence) before calling.
-- @tparam int count number of cursor positions to read
-- @treturn table cursor positions, each entry is an array with row and column
function M.read_cursor_pos(count)
  assert(type(count) == "number", "count must be an integer greater than 0")
  -- read responses
  local result = {}
  while true do
    local seq, typ, part = M.sys_readansi(0.5, bsleep) -- 500ms timeout, max time for terminal to respond
    if seq == nil and typ == "timeout" then
      error("no response from terminal, this is unexpected")
    end
    if typ == "ansi" then
      local row, col = seq:match("^\27%[(%d+);(%d+)R$")
      if row and col then
        result[#result+1] = { tonumber(row), tonumber(col) }
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



return M
