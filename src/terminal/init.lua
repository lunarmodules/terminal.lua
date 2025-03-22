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
local utils = require "terminal.utils"

-- Push the module table already in `package.loaded` to avoid circular dependencies
package.loaded["terminal"] = M
-- load the submodules
M.input = require("terminal.input")
M.output = require("terminal.output")
M.clear = require("terminal.clear")
M.scroll = require("terminal.scroll")
M.cursor = require("terminal.cursor")
M.draw = require("terminal.draw")
M.progress = require("terminal.progress")
M.width = require("terminal.width")
-- create locals
local output = M.output
local scroll = M.scroll
local cursor = M.cursor


-- Set defaults for sleep functions
M._bsleep = sys.sleep  -- a blocking sleep function
M._sleep = sys.sleep   -- a (optionally) non-blocking sleep function



--=============================================================================
-- text: colors & attributes
--=============================================================================
-- Text colors and attributes.
-- Managing the text color and attributes.
-- @section textcolor

local fg_color_reset = "\27[39m"
local bg_color_reset = "\27[49m"
local attribute_reset = "\27[0m"
local underline_on = "\27[4m"
local underline_off = "\27[24m"
local blink_on = "\27[5m"
local blink_off = "\27[25m"
local reverse_on = "\27[7m"
local reverse_off = "\27[27m"

local fg_base_colors = utils.make_lookup("foreground color string", {
  black = "\27[30m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  magenta = "\27[35m",
  cyan = "\27[36m",
  white = "\27[37m",
})

local bg_base_colors = utils.make_lookup("background color string",{
  black = "\27[40m",
  red = "\27[41m",
  green = "\27[42m",
  yellow = "\27[43m",
  blue = "\27[44m",
  magenta = "\27[45m",
  cyan = "\27[46m",
  white = "\27[47m",
})

local default_colors = {
  fg = fg_color_reset, -- reset fg
  bg = bg_color_reset, -- reset bg
  brightness = 2, -- normal
  underline = false,
  blink = false,
  reverse = false,
  ansi = fg_color_reset .. bg_color_reset .. attribute_reset,
}

local _colorstack = {
  default_colors,
}

-- Takes a color name/scheme by user and returns the ansi sequence for it.
-- This function takes three color types:
--
-- 1. base colors: black, red, green, yellow, blue, magenta, cyan, white. Use as `color("red")`.
-- 2. extended colors: a number between 0 and 255. Use as `color(123)`.
-- 3. RGB colors: three numbers between 0 and 255. Use as `color(123, 123, 123)`.
-- @tparam integer|string r the red value (in case of RGB), a number for extended colors, or a string color for base-colors
-- @tparam[opt] number g the green value (in case of RGB), nil otherwise
-- @tparam[opt] number b the blue value (in case of RGB), nil otherwise
-- @tparam[opt] boolean fg true for foreground, false for background
-- @treturn string ansi sequence to write to the terminal
local function colorcode(r, g, b, fg)
  if type(r) == "string" then
    -- a string based color
    return fg and fg_base_colors[r] or bg_base_colors[r]
  end

  if type(r) ~= "number" or r < 0 or r > 255 then
    return error("expected arg #1 to be a string or an integer 0-255, got " .. tostring(r) .. " (" .. type(r) .. ")", 2)
  end
  r = tostring(math.floor(r))
  if g == nil then
    -- no g set, then r is the extended color
    return fg and ("\27[38;5;" .. r .. "m") or ("\27[48;5;" .. r .. "m")
  end

  if type(g) ~= "number" or g < 0 or g > 255 then
    return error("expected arg #2 to be a number 0-255, got " .. tostring(g) .. " (" .. type(g) .. ")", 2)
  end
  g = tostring(math.floor(g))

  if type(b) ~= "number" or b < 0 or b > 255 then
    return error("expected arg #3 to be a number 0-255, got " .. tostring(b) .. " (" .. type(b) .. ")", 2)
  end
  b = tostring(math.floor(b))

  return fg and ("\27[38;2;" .. r .. ";" .. g .. ";" .. b .. "m") or ("\27[48;2;" .. r .. ";" .. g .. ";" .. b .. "m")
end

--- Creates an ansi sequence to set the foreground color without writing it to the terminal.
-- This function takes three color types:
--
-- 1. base colors: black, red, green, yellow, blue, magenta, cyan, white. Use as `color_fgs("red")`.
-- 2. extended colors: a number between 0 and 255. Use as `color_fgs(123)`.
-- 3. RGB colors: three numbers between 0 and 255. Use as `color_fgs(123, 123, 123)`.
--
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.color_fgs(r, g, b)
  return colorcode(r, g, b, true)
end

--- Sets the foreground color and writes it to the terminal.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @return true
-- @within textcolor
function M.color_fg(r, g, b)
  output.write(M.color_fgs(r, g, b))
  return true
end

--- Creates an ansi sequence to set the background color without writing it to the terminal.
-- This function takes three color types:
--
-- 1. base colors: black, red, green, yellow, blue, magenta, cyan, white. Use as `color_bgs("red")`.
-- 2. extended colors: a number between 0 and 255. Use as `color_bgs(123)`.
-- 3. RGB colors: three numbers between 0 and 255. Use as `color_bgs(123, 123, 123)`.
--
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.color_bgs(r, g, b)
  return colorcode(r, g, b, false)
end

--- Sets the background color and writes it to the terminal.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @return true
-- @within textcolor
function M.color_bg(r, g, b)
  output.write(M.color_bgs(r, g, b))
  return true
end

--- Creates an ansi sequence to set the underline attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.underline_ons()
  return underline_on
end

--- Sets the underline attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.underline_on()
  output.write(M.underline_ons())
  return true
end

--- Creates an ansi sequence to unset the underline attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.underline_offs()
  return underline_off
end

--- Unsets the underline attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.underline_off()
  output.write(M.underline_offs())
  return true
end

--- Creates an ansi sequence to set the blink attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.blink_ons()
  return blink_on
end

--- Sets the blink attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.blink_on()
  output.write(M.blink_ons())
  return true
end

--- Creates an ansi sequence to unset the blink attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.blink_offs()
  return blink_off
end

--- Unsets the blink attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.blink_off()
  output.write(M.blink_offs())
  return true
end

--- Creates an ansi sequence to set the reverse attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.reverse_ons()
  return reverse_on
end

--- Sets the reverse attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.reverse_on()
  output.write(M.reverse_ons())
  return true
end

--- Creates an ansi sequence to unset the reverse attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.reverse_offs()
  return reverse_off
end

--- Unsets the reverse attribute and writes it to the terminal.
-- @return true
-- @within textcolor
function M.reverse_off()
  output.write(M.reverse_offs())
  return true
end


-- lookup brightness levels
local _brightness = utils.make_lookup("brightness level", {
  off = 0,
  low = 1,
  normal = 2,
  high = 3,
  [0] = 0,
  [1] = 1,
  [2] = 2,
  [3] = 3,
  -- common terminal codes
  invisible = 0,
  dim = 1,
  bright = 3,
  bold = 3,
})

-- ansi sequences to apply for each brightness level (always works, does not need a reset)
-- (a reset would also have an effect on underline, blink, and reverse)
local _brightness_sequence = {
  -- 0 = remove bright and dim, apply invisible
  [0] = "\027[22m\027[8m",
  -- 1 = remove bold/dim, remove invisible, set dim
  [1] = "\027[22m\027[28m\027[2m",
  -- 2 = normal, remove dim, bright, and invisible
  [2] = "\027[22m\027[28m",
  -- 3 = remove bold/dim, remove invisible, set bright/bold
  [3] = "\027[22m\027[28m\027[1m",
}

-- same thing, but simplified, if done AFTER an attribute reset
local _brightness_sequence_after_reset = {
  -- 0 = invisible
  [0] = "\027[8m",
  -- 1 = dim
  [1] = "\027[2m",
  -- 2 = normal (no additional attributes needed after reset)
  [2] = "",
  -- 3 = bright/bold
  [3] = "\027[1m",
}


--- Creates an ansi sequence to set the brightness without writing it to the terminal.
-- `brightness` can be one of the following:
--
-- - `0`, `"off"`, or `"invisble"` for invisible
-- - `1`, `"low"`, or `"dim"` for dim
-- - `2`, `"normal"` for normal
-- - `3`, `"high"`, `"bright"`, or `"bold"` for bright
--
-- @tparam string|integer brightness the brightness to set
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor
function M.brightnesss(brightness)
  return _brightness_sequence[_brightness[brightness]]
end

--- Sets the brightness and writes it to the terminal.
-- @tparam string|integer brightness the brightness to set
-- @return true
-- @within textcolor
function M.brightness(brightness)
  output.write(M.brightnesss(brightness))
  return true
end


--=============================================================================
-- text_stack: colors & attributes
--=============================================================================
-- Text colors and attributes stack.
-- Stack for managing the text color and attributes.
-- @section textcolor_stack


local function newtext(attr)
  local last = _colorstack[#_colorstack]
  local fg_color = attr.fg or attr.fg_r
  local bg_color = attr.bg or attr.bg_r
  local new = {
    fg         = fg_color        == nil and last.fg         or colorcode(fg_color, attr.fg_g, attr.fg_b, true),
    bg         = bg_color        == nil and last.bg         or colorcode(bg_color, attr.bg_g, attr.bg_b, false),
    brightness = attr.brightness == nil and last.brightness or _brightness[attr.brightness],
    underline  = attr.underline  == nil and last.underline  or (not not attr.underline),
    blink      = attr.blink      == nil and last.blink      or (not not attr.blink),
    reverse    = attr.reverse    == nil and last.reverse    or (not not attr.reverse),
  }
  new.ansi = attribute_reset .. new.fg .. new.bg ..
    _brightness_sequence_after_reset[new.brightness] ..
    (new.underline and underline_on or "") ..
    (new.blink and blink_on or "") ..
    (new.reverse and reverse_on or "")
  -- print("newtext:", (new.ansi:gsub("\27", "\\27")))
  return new
end

--- Creates an ansi sequence to set the text attributes without writing it to the terminal.
-- Only set what you change. Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, with keys:
-- @tparam[opt] string|integer attr.fg the foreground color to set. Base color (string), or extended color (number). Takes precedence of `fg_r`, `fg_g`, `fg_b`.
-- @tparam[opt] integer attr.fg_r the red value of the foreground color to set.
-- @tparam[opt] integer attr.fg_g the green value of the foreground color to set.
-- @tparam[opt] integer attr.fg_b the blue value of the foreground color to set.
-- @tparam[opt] string|integer attr.bg the background color to set. Base color (string), or extended color (number). Takes precedence of `bg_r`, `bg_g`, `bg_b`.
-- @tparam[opt] integer attr.bg_r the red value of the background color to set.
-- @tparam[opt] integer attr.bg_g the green value of the background color to set.
-- @tparam[opt] integer attr.bg_b the blue value of the background color to set.
-- @tparam[opt] string|number attr.brightness the brightness level to set
-- @tparam[opt] boolean attr.underline whether to set underline
-- @tparam[opt] boolean attr.blink whether to set blink
-- @tparam[opt] boolean attr.reverse whether to set reverse
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor_stack
function M.textsets(attr)
  local new = newtext(attr)
  return new.ansi
end

--- Sets the text attributes and writes it to the terminal.
-- Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, see `textsets` for details.
-- @return true
-- @within textcolor_stack
function M.textset(attr)
  output.write(newtext(attr).ansi)
  return true
end

--- Pushes the current attributes onto the stack, and returns an ansi sequence to set the new attributes without writing it to the terminal.
-- Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, see `textsets` for details.
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor_stack
function M.textpushs(attr)
  local new = newtext(attr)
  _colorstack[#_colorstack + 1] = new
  return new.ansi
end

--- Pushes the current attributes onto the stack, and writes an ansi sequence to set the new attributes to the terminal.
-- Every element omitted in the `attr` table will be taken from the current top of the stack.
-- @tparam table attr the attributes to set, see `textsets` for details.
-- @return true
-- @within textcolor_stack
function M.textpush(attr)
  output.write(M.textpushs(attr))
  return true
end

--- Pops n attributes off the stack (and returns the last one), without writing it to the terminal.
-- @tparam[opt=1] number n number of attributes to pop
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor_stack
function M.textpops(n)
  n = n or 1
  local newtop = math.max(#_colorstack - n, 1)
  for i = newtop + 1, #_colorstack do
    _colorstack[i] = nil
  end
  return _colorstack[#_colorstack].ansi
end

--- Pops n attributes off the stack, and writes the last one to the terminal.
-- @tparam[opt=1] number n number of attributes to pop
-- @return true
-- @within textcolor_stack
function M.textpop(n)
  output.write(M.textpops(n))
  return true
end

--- Re-applies the current attributes (returns it, does not write it to the terminal).
-- @treturn string ansi sequence to write to the terminal
-- @within textcolor_stack
function M.textapplys()
  return _colorstack[#_colorstack].ansi
end

--- Re-applies the current attributes, and writes it to the terminal.
-- @return true
-- @within textcolor_stack
function M.textapply()
  output.write(_colorstack[#_colorstack].ansi)
  return true
end



--=============================================================================
-- terminal initialization, shutdown and miscellanea
--=============================================================================
--- Initialization.
-- Initialization, termination and miscellaneous functions.
-- @section initialization



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
  -- @within initialization
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
  -- @within initialization
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
  -- @within initialization
  function M.shutdown()
    assert(M.ready(), "terminal not initialized")

    -- restore all stacks
    local r,c = cursor.position.get() -- Mac: scroll-region reset changes cursor pos to 1,1, so store it
    output.write(
      cursor.shape.stack.pops(math.huge),
      cursor.visible.stack.pops(math.huge),
      M.textpops(math.huge),
      scroll.stack.pops(math.huge),
      cursor.position.sets(r,c) -- restore cursor pos
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
-- @within initialization
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
