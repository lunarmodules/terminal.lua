--- Terminal library for Lua.
--
-- This terminal library builds upon the cross-platform terminal capabilities of
-- [LuaSystem](https://github.com/lunarmodules/luasystem). As such
-- it works in modern terminals on Windows, Unix, and Mac systems.
--
-- It provides a simple and consistent interface to the terminal, allowing for cursor positioning,
-- cursor shape and visibility, text formatting, and more.
--
-- For generic instruction please read the [introduction](topics/01-introduction.md.html).
--
-- @copyright Copyright (c) 2024-2024 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE.md`.

local M = {
  _VERSION = "0.0.1",
  _COPYRIGHT = "Copyright (c) 2024-2024 Thijs Schreijer",
  _DESCRIPTION = "Cross platform terminal library for Lua (Windows/Unix/Mac)",
}


local pack, unpack do
  -- nil-safe versions of pack/unpack
  local oldunpack = _G.unpack or table.unpack -- luacheck: ignore
  pack = function(...) return { n = select("#", ...), ... } end
  unpack = function(t, i, j) return oldunpack(t, i or 1, j or t.n or #t) end
end


local sys = require "system"

-- Push the module table already in `package.loaded` to avoid circular dependencies
package.loaded["terminal"] = M
-- load the submodules
M.input = require("terminal.input")
M.output = require("terminal.output")
M.clear = require("terminal.clear")
M.scroll = require("terminal.scroll")
M.cursor = require("terminal.cursor")
M.text = require("terminal.text")
M.draw = require("terminal.draw")
M.progress = require("terminal.progress")
-- create locals
local output = M.output
local scroll = M.scroll
local cursor = M.cursor
local text = M.text


-- Set defaults for sleep functions
M._bsleep = sys.sleep  -- a blocking sleep function
M._sleep = sys.sleep   -- a (optionally) non-blocking sleep function



--- Returns a string sequence to make the terminal beep.
-- @treturn string ansi sequence to write to the terminal
function M.beeps()
  return "\a"
end



--- Write a sequence to the terminal to make it beep.
-- @return true
function M.beep()
  output.write(M.beeps())
  return true
end



do
  local termbackup
  local reset = "\27[0m"
  local savescreen = "\27[?1049h" -- save cursor pos + switch to alternate screen buffer
  local restorescreen = "\27[?1049l" -- restore cursor pos + switch to main screen buffer



  --- Returns whether the terminal has been initialized and is ready for use.
  -- @treturn boolean true if the terminal has been initialized
  function M.ready()
    return termbackup ~= nil
  end



  --- Initializes the terminal for use.
  -- Makes a backup of the current terminal settings.
  -- Sets input to non-blocking, disables canonical mode and echo, and enables ANSI processing.
  -- The preferred way to initialize the terminal is through `initwrap`, since that ensures settings
  -- are properly restored in case of an error, and don't leave the terminal in an inconsistent state
  -- for the user after exit.
  -- @tparam[opt] table opts options table, with keys:
  -- @tparam[opt=false] boolean opts.displaybackup if true, the current terminal display is also
  -- backed up (by switching to the alternate screen buffer).
  -- @tparam[opt=io.stderr] filehandle opts.filehandle the stream to use for output
  -- @tparam[opt=sys.sleep] function opts.bsleep the blocking sleep function to use.
  -- This should never be set to a yielding sleep function! This function
  -- will be used by the `terminal.write` and `terminal.print` to prevent buffer-overflows and
  -- truncation when writing to the terminal. And by `cursor.position.get` when reading the cursor position.
  -- @tparam[opt=sys.sleep] function opts.sleep the default sleep function to use for `readansi`.
  -- In an async application (coroutines), this should be a yielding sleep function, eg. `copas.pause`.
  -- @return true
  function M.initialize(opts)
    assert(not M.ready(), "terminal already initialized")

    opts = opts or {}
    assert(type(opts) == "table", "expected opts to be a table, got " .. type(opts))

    local filehandle = opts.filehandle or io.stderr
    assert(io.type(filehandle) == 'file', "invalid opts.filehandle")
    output.set_stream(filehandle)

    M._bsleep = opts.bsleep or sys.sleep
    assert(type(M._bsleep) == "function", "invalid opts.bsleep function, expected a function, got " .. type(opts.bsleep))

    M._asleep = opts.sleep or sys.sleep
    assert(type(M._asleep) == "function", "invalid opts.sleep function, expected a function, got " .. type(opts.sleep))

    termbackup = sys.termbackup()
    if opts.displaybackup then
      output.write(savescreen)
      termbackup.displaybackup = true
    end

    -- set Windows output to UTF-8
    sys.setconsoleoutputcp(65001)

    -- setup Windows console to handle ANSI processing, disable echo and line input (canonical mode)
    sys.setconsoleflags(io.stdout, sys.getconsoleflags(io.stdout) + sys.COF_VIRTUAL_TERMINAL_PROCESSING)
    sys.setconsoleflags(io.stdin, sys.getconsoleflags(io.stdin) + sys.CIF_VIRTUAL_TERMINAL_INPUT - sys.CIF_ECHO_INPUT - sys.CIF_LINE_INPUT)

    -- setup Posix terminal to disable canonical mode and echo
    sys.tcsetattr(io.stdin, sys.TCSANOW, {
      lflag = sys.tcgetattr(io.stdin).lflag - sys.L_ICANON - sys.L_ECHO,
    })
    -- setup stdin to non-blocking mode
    sys.setnonblock(io.stdin, true)

    return true
  end



  --- Shuts down the terminal, restoring the terminal settings.
  -- @return true
  function M.shutdown()
    assert(M.ready(), "terminal not initialized")

    -- restore all stacks
    local r,c = cursor.position.get() -- Mac: scroll-region reset changes cursor pos to 1,1, so store it
    output.write(
      cursor.shape.stack.pop_seq(math.huge),
      cursor.visible.stack.pop_seq(math.huge),
      text.stack.pop_seq(math.huge),
      scroll.stack.pop_seq(math.huge),
      cursor.position.set_seq(r,c) -- restore cursor pos
    )
    output.flush()

    if termbackup.displaybackup then
      output.write(restorescreen)
      output.flush()
    end
    output.write(reset)
    output.flush()

    sys.termrestore(termbackup)

    M._asleep = sys.sleep
    M._bsleep = sys.sleep
    termbackup = nil

    return true
  end
end



--- Wrap a function in `initialize` and `shutdown` calls.
-- When an error occurs, and the application exits, the terminal might not be properly shut down.
-- This function wraps a function in calls to `initialize` and `shutdown`, ensuring the terminal is properly shut down.
-- @tparam[opt] table opts options table, to pass to `initialize`.
-- @tparam function main the function to wrap
-- @param ... any parameters to pass to the main function
-- @treturn any the return values of the wrapped function, or nil+err in case of an error
-- @usage local function main(param1, param2)
--   -- your main app functionality here
--
--   return true -- return truthy to pass assertion below
-- end
--
-- local opts = {
--   filehandle = io.stderr,
--   displaybackup = true,
-- }
-- assert(t.initwrap(opts, main, "one", "two")) -- assert to rethrow any error after termimal restore
function M.initwrap(opts, main, ...)
  assert(type(main) == "function", "expected main to be a function, got " .. type(main))
  M.initialize(opts)

  local results
  local ok, err = xpcall(function(...)
    results = pack(main(...))
  end, debug.traceback, ...)

  M.shutdown()

  if not ok then
    return nil, err
  end
  return unpack(results)
end



return M
