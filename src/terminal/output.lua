--- Module for writing output.
--
-- *Note:* This module will be available from the main `terminal` module, without
-- explicitly requiring it.
-- @usage
-- local terminal = require "terminal"
-- terminal.initialize()
--
-- terminal.output.write("hello world")
-- @module terminal.output

local M = {}
package.loaded["terminal.output"] = M -- Register the module early to avoid circular dependencies
local terminal = require("terminal")


local t = io.stderr -- the terminal/stream to operate on

local chunksize = 512 -- chunk size to write in one go
local bytecount_left = chunksize -- number of bytes to write before flush+sleep required
local delay = 0.001 -- delay in seconds after each chunk write



local pack do
  -- nil-safe versions of pack/unpack
  local oldunpack = _G.unpack or table.unpack -- luacheck: ignore
  pack = function(...) return { n = select("#", ...), ... } end
  --unpack = function(t, i, j) return oldunpack(t, i or 1, j or t.n or #t) end
end



--- Set the stream to operate on.
-- This can be used to redirect output to a different stream.
-- The default value at start is `io.stderr`.
-- @tparam file filehandle the stream to operate on (`io.stderr` or `io.stdout`)
-- @return true
function M.set_stream(filehandle)
  assert(io.type(filehandle) == 'file', "invalid stream, expected a filehandle")
  t = filehandle
  return true
end



--- Writes to the stream in chunks.
-- Parameters are written to the stream, and flushed after each chunk. A small sleep is
-- added after each chunk to allow the terminal to process the data.
-- This is done to prevent the terminal buffer from overrunning and dropping data.
--
-- Differences from the standard Lua write function:
--
-- - parameters will be tostring-ed before writing
-- @param ... the values to write
-- @return the return value of the stream's `write` function
function M.write(...)
  local args = pack(...)
  if args.n == 0 then
    return t:write("") -- ensure we return the same return values as the stream's write function
  end

  for i = 1, args.n do
    args[i] = tostring(args[i])
  end
  local data = table.concat(args)

  -- write to stream, in chunks. flush and sleep in between
  local ok, err
  while #data > 0 do
    local chunk = data:sub(1, bytecount_left)
    data = data:sub(bytecount_left + 1)

    ok, err = t:write(chunk)
    if not ok then
      return ok, err
    end

    bytecount_left = bytecount_left - #chunk
    if bytecount_left <= 0 then
      bytecount_left = chunksize
      t:flush()
      -- sleep a bit to allow the terminal to process the data
      terminal._bsleep(delay) -- blocking because we do not want to risk yielding here
    end
  end

  return ok, err
end



--- Prints to the stream in chunks.
-- A `print` compatible function that safely writes output to the stream.
-- @param ... the values to write
function M.print(...)
  local args = pack(...)
  for i = 1, args.n do
    args[i] = tostring(args[i])
  end
  M.write(table.concat(args, "\t"), "\n")
end



--- Flushes the stream.
-- @return the return value of the stream's `flush` function
function M.flush()
  return t:flush()
end


return M
