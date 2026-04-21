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



do
  local termbackup
  local reset = "\27[0m"
  local savescreen = "\27[?1049h" -- save cursor pos + switch to alternate screen buffer
  local restorescreen = "\27[?1049l" -- restore cursor pos + switch to main screen buffer
  local is_windows = package.config:sub(1, 1) == "\\"

  local function command_ok(...)
    local ok, _, code = os.execute(...)
    if type(ok) == "number" then
      return ok == 0
    end
    if type(ok) == "boolean" then
      return ok and (code == nil or code == 0)
    end
    return false
  end

  local function try_stty(args)
    return command_ok("stty " .. args .. " < /dev/tty 2>/dev/null")
      or command_ok("stty " .. args .. " 2>/dev/null")
      or command_ok("stty " .. args .. " < CON 2>nul")
      or command_ok("stty " .. args .. " 2>nul")
  end

  local function is_console_flag_error(err)
    if type(err) ~= "string" then
      return false
    end
    return err:find("setconsoleflags", 1, true) ~= nil
      and err:find("invalid flags", 1, true) ~= nil
  end

  local function restore_without_console_flags(backup)
    -- Best-effort fallback for Windows pseudo terminals where restoring Win32
    -- console flags fails, but POSIX-ish tty settings/non-block mode can still
    -- be restored.
    if backup.term_in then pcall(sys.tcsetattr, io.stdin, sys.TCSANOW, backup.term_in) end
    if backup.term_out then pcall(sys.tcsetattr, io.stdout, sys.TCSANOW, backup.term_out) end
    if backup.term_err then pcall(sys.tcsetattr, io.stderr, sys.TCSANOW, backup.term_err) end

    if backup.block_in ~= nil then pcall(sys.setnonblock, io.stdin, backup.block_in) end
    if backup.block_out ~= nil then pcall(sys.setnonblock, io.stdout, backup.block_out) end
    if backup.block_err ~= nil then pcall(sys.setnonblock, io.stderr, backup.block_err) end

    if backup.consoleoutcodepage then pcall(sys.setconsoleoutputcp, backup.consoleoutcodepage) end
    if backup.consolecp then pcall(sys.setconsolecp, backup.consolecp) end
  end



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
  -- @tparam[opt=false] boolean opts.skip_width_detection Set to `true`, to skip ambiguous-width detection.
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
    if is_windows then
      local cflags_out = sys.getconsoleflags(io.stdout)
      local cflags_in = sys.getconsoleflags(io.stdin)
      local can_use_console_flags = cflags_out ~= nil and cflags_in ~= nil

      if can_use_console_flags then
        local cof_vtp = sys.COF_VIRTUAL_TERMINAL_PROCESSING or sys.bitflag(4)
        local cif_vti  = sys.CIF_VIRTUAL_TERMINAL_INPUT or sys.bitflag(0x0200)
        local new_out = cflags_out + cof_vtp
        local new_in = cflags_in + cif_vti

        -- Some Windows pseudo terminals (eg. ConPTY hosts) reject Win32
        -- console flag changes. Keep this best-effort.
        -- We only try to enable VTP/VTI here. Input still works because
        -- luasystem `getch` already reads single key presses on Windows.
        pcall(sys.setconsoleflags, io.stdout, new_out)
        pcall(sys.setconsoleflags, io.stdin, new_in)
      end
    end

    -- setup Posix terminal to disable canonical mode and echo (no-op mock on Windows)
    local attr = sys.tcgetattr(io.stdin)
    if attr and attr.lflag then
      sys.tcsetattr(io.stdin, sys.TCSANOW, {
        lflag = attr.lflag - sys.L_ICANON - sys.L_ECHO,
      })
    end

    -- setup stdin to non-blocking mode
    sys.setnonblock(io.stdin, true)

    if opts.disable_sigint then
      -- let the app handle ctrl-c, don't send SIGINT
      local attr_sig = sys.tcgetattr(io.stdin)
      if attr_sig and attr_sig.lflag then
        sys.tcsetattr(io.stdin, sys.TCSANOW, {
          lflag = attr_sig.lflag - sys.L_ISIG,
        })
      end
      if is_windows then
        local cflags_sig = sys.getconsoleflags(io.stdin)
        if cflags_sig ~= nil then
          pcall(sys.setconsoleflags, io.stdin, cflags_sig - sys.CIF_PROCESSED_INPUT)
        else
          -- Best effort for pseudo terminals where Win32 console flags are unavailable.
          try_stty("intr ''")
        end
      end
    end

    if not opts.skip_width_detection then
      text.width.detect_ambiguous_width()
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
    cursor.shape.pop(math.huge)
    cursor.visible.pop(math.huge)
    text.pop(math.huge)
    scroll.pop(math.huge)

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

    local ok_restore, restore_err = pcall(sys.termrestore, termbackup)
    if (not ok_restore) and is_windows and is_console_flag_error(restore_err) then
      -- Pseudo terminals on Windows (eg. ConPTY-based hosts) can reject
      -- restoring Win32 console flags captured by `termbackup`.
      -- Fall back to restoring non-console state to avoid leaving tty mode in
      -- a broken state for the shell session.
      restore_without_console_flags(termbackup)
    elseif not ok_restore then
      error(restore_err, 2)
    end

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
