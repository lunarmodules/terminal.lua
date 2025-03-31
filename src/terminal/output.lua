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
local delay = 0.050 -- delay in seconds added after each retry


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



local writer do
  local function write_windows(data)
    return t:write(data)
  end

  local function write_posix(data)
    local ok, err, errno, tries
    local i = 1
    local size = #data
    while i <= size do
      ok, err, errno = t:write(data:sub(i, i)) -- only 1 byte at a time, thx OSX :(
      if ok then
        t:flush()
        i = i + 1
        tries = nil
      else
        if errno == 11 or errno == 35 then
          -- EAGAIN or EWOULDBLOCK, retry
          tries = (tries or 0) + 1
          t:flush()
          terminal._bsleep(delay * tries) -- blocking because we do not want to risk yielding here
        else
          -- some other error
          return ok, err, errno
        end
      end
    end

    return ok, err, errno
  end


  -- select the writer function based on the platform
  if package.config:sub(1, 1) == "\\" then
    writer = write_windows
  else
    writer = write_posix
  end
end



--- Writes to the stream.
-- This is a safer write-function than the standard Lua one.
-- Differences from the standard Lua write function:
--
-- - parameters will be tostring-ed before writing
-- - will retry on EAGAIN or EWOULDBLOCK errors (after a short sleep)
-- - will flush the stream
-- @param ... the values to write
-- @return the return value of the stream's `write` function
function M.write(...)
  local args = pack(...)
  for i = 1, args.n do
    args[i] = tostring(args[i])
  end

  local data = table.concat(args)

  if data == "" then
    return t:write("")
  end

  return writer(data)
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
