--- Module for writing output.
--
-- *Note:* This module will be available from the main `terminal` module, without
-- explicitly requiring it.
--
-- *Example:*
--     local terminal = require "terminal"
--     terminal.initialize()
--
--     terminal.output.write("hello world")
-- @module terminal.output

local M = {}
package.loaded["terminal.output"] = M -- Register the module early to avoid circular dependencies


local t = io.stderr -- the terminal/stream to operate on


local pack do
  -- nil-safe versions of pack/unpack
  local oldunpack = _G.unpack or table.unpack -- luacheck: ignore
  pack = function(...) return { n = select("#", ...), ... } end
  --unpack = function(t, i, j) return oldunpack(t, i or 1, j or t.n or #t) end
end



--- Set the stream to operate on.
-- This can be used to redirect output to a different stream.
-- The default value at start is `io.stderr`.
--
-- Instead of calling this directly, it is probably better to use the
-- `terminal.initialize` function.
-- @tparam file filehandle the stream to operate on (`io.stderr` or `io.stdout`)
-- @return true
function M.set_stream(filehandle)
  assert(io.type(filehandle) == 'file', "invalid stream, expected a filehandle")
  t = filehandle
  return true
end



--- Writes to the stream.
-- This is a safer write-function than the standard Lua one.
-- Differences from the standard Lua write function:
--
-- - parameters will be tostring-ed before writing
-- - will flush the stream
-- @param ... the values to write
-- @return the return value of the stream's `write` function
function M.write(...)
  local args = pack(...)
  for i = 1, args.n do
    args[i] = tostring(args[i])
  end

  local ok, err, errno = t:write(table.concat(args))
  if not ok then
    return ok, err, errno
  end

  t:flush()

  return ok, err, errno
end



--- Prints to the stream.
-- A `print` compatible function that safely writes output to the stream.
-- @param ... the values to write
function M.print(...)
  local args = pack(...)
  for i = 1, args.n do
    args[i] = tostring(args[i])
  end

  t:write(table.concat(args, "\t"), "\n")
  t:flush()

  return true
end



--- Flushes the stream.
-- @return the return value of the stream's `flush` function
function M.flush()
  return t:flush()
end



return M
