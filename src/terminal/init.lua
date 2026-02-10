--- Terminal library for Lua.
--
-- This terminal library builds upon the cross-platform terminal capabilities of
-- [LuaSystem](https://github.com/lunarmodules/luasystem). As such
-- it works in modern terminals on Windows, Unix, and Mac systems.
--
-- It provides a simple and consistent interface to the terminal, allowing for cursor positioning,
-- cursor shape and visibility, text formatting, and more.
--
-- For generic instruction please read the [introduction](../topics/01-introduction.md.html).
--
-- @copyright Copyright (c) 2024-2025 Thijs Schreijer
-- @author Thijs Schreijer
-- @license MIT, see `LICENSE.md`.

local M = {
  _VERSION = "0.0.1",
  _COPYRIGHT = "Copyright (c) 2024-2025 Thijs Schreijer",
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
-- load the submodules; all but object; editline, sequence, cli.*, ui.*
M.input = require("terminal.input")
M.output = require("terminal.output")
M.clear = require("terminal.clear")
M.scroll = require("terminal.scroll")
M.cursor = require("terminal.cursor")
M.text = require("terminal.text")
M.draw = require("terminal.draw")
M.progress = require("terminal.progress")
M.utils = require("terminal.utils")
-- create locals
local output = M.output
local scroll = M.scroll
local cursor = M.cursor
local text = M.text


-- Set defaults for sleep functions
M._bsleep = sys.sleep  -- a blocking sleep function
M._sleep = sys.sleep   -- a (optionally) non-blocking sleep function



--- Returns the terminal size in rows and columns.
-- Just a convenience, maps 1-on-1 to `system.termsize`.
-- @treturn[1] number number of rows
-- @treturn[1] number number of columns
-- @treturn[2] nil on error
-- @treturn[2] string error message
-- @function size
M.size = sys.termsize



--- Returns a string sequence to make the terminal beep.
-- @treturn string ansi sequence to write to the terminal
function M.bell_seq()
  return "\a"
end



--- Write a sequence to the terminal to make it beep.
-- @return true
function M.bell()
  output.write(M.bell_seq())
  return true
end



--- Preload known characters into the width-cache.
-- Typically this should be called right after initialization. It will check default
-- characters in use by this library, and the optional specified characters in `str`.
-- Characters loaded will be the `terminal.draw.box_fmt` formats, and the `progress` spinner sprites.
-- Uses `terminal.text.width.test` to test the widths of the characters.
-- @tparam[opt] string str additional character string to preload
-- @return true
-- @within Initialization
function M.preload_widths(str)
  text.width.test((str or "") .. M.progress._spinner_fmt_chars() .. M.draw._box_fmt_chars())
  return true
end



do
  local termbackup
  local reset = "\27[0m"
  local savescreen = "\27[?1049h" -- save cursor pos + switch to alternate screen buffer
  local restorescreen = "\27[?1049l" -- restore cursor pos + switch to main screen buffer



  --- Returns whether the terminal has been initialized and is ready for use.
  -- @treturn boolean true if the terminal has been initialized
  -- @within Initialization
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
  -- will be used by `terminal.cursor.position.get` when reading the cursor position.
  -- @tparam[opt=sys.sleep] function opts.sleep the default sleep function to use for `terminal.input.readansi`.
  -- In an async application (coroutines), this should be a yielding sleep function, eg. `copas.pause`.
  -- @tparam[opt=true] boolean opts.autotermrestore if `false`, the terminal settings will not be restored.
  -- See [`luasystem.autotermrestore`](https://lunarmodules.github.io/luasystem/modules/system.html#autotermrestore).
  -- @tparam[opt=false] boolean opts.disable_sigint if `true`, the terminal will not send a SIGINT signal
  -- on Ctrl-C. Disables Ctrl-C, Ctrl-Z, and Ctrl-\, which allows the application to handle them.
  -- @return true
  -- @within Initialization
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

    if opts.autotermrestore ~= nil then
      sys.autotermrestore()
    end

    sys.detachfds()

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

    if opts.disable_sigint then
      -- let the app handle ctrl-c, don't send SIGINT
      sys.tcsetattr(io.stdin, sys.TCSANOW, {
        lflag = sys.tcgetattr(io.stdin).lflag - sys.L_ISIG,
      })
      sys.setconsoleflags(io.stdin, sys.getconsoleflags(io.stdin) - sys.CIF_PROCESSED_INPUT)
    end

    return true
  end



  --- Shuts down the terminal, restoring the terminal settings.
  -- @return true
  -- @within Initialization
  function M.shutdown()
    assert(M.ready(), "terminal not initialized")

    -- restore all stacks
    local ok, r,c = pcall(cursor.position.get) -- Mac: scroll-region reset changes cursor pos to 1,1, so store it
    cursor.shape.stack.pop(math.huge)
    cursor.visible.stack.pop(math.huge)
    text.stack.pop(math.huge)
    scroll.stack.pop(math.huge)

    if ok and r then
      cursor.position.set(r,c) -- restore cursor pos
    end
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
-- If an error is caught, it first shutsdown the terminal and then rethrows the error.
-- @tparam function main the function to wrap
-- @tparam[opt] table opts options table, see `initialize` for details.
-- @treturn function wrapped function
-- @within Initialization
-- @usage
-- local function main(param1, param2)
--
--   -- your main app functionality here
--   error("oops...")
--
-- end
--
-- main = t.initwrap(main, {
--   filehandle = io.stderr,
--   displaybackup = true,
-- })
--
-- main("one", "two") -- rethrows any error after termimal restore
function M.initwrap(main, opts)
  assert(type(main) == "function", "expected arg#1 to be a function, got " .. type(main))

  return function(...)
    M.initialize(opts)

    local args = pack(...)
    local results
    local ok, err = xpcall(function()
      results = pack(main(unpack(args)))
    end, debug.traceback)

    M.shutdown()

    if not ok then
      return error(err, 2)
    end
    return unpack(results)
  end
end



return M
