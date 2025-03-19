--- Module for setting text colors and attributes.
-- contains other functionality such as enabling/disabling text attributes like underline, blinking
-- and reversing. Also contains functionality for setting brightness levels.
-- @module terminal.color
-- @usage
-- local color = require("terminal.color")
local M = {}
package.loaded["terminal.color"] = M
local output = require("terminal.output")

local fg_color_reset = "\27[39m"
local bg_color_reset = "\27[49m"
local attribute_reset = "\27[0m"
local underline_on = "\27[4m"
local underline_off = "\27[24m"
local blink_on = "\27[5m"
local blink_off = "\27[25m"
local reverse_on = "\27[7m"
local reverse_off = "\27[27m"

M.fg_base_colors = setmetatable({
  black = "\27[30m",
  red = "\27[31m",
  green = "\27[32m",
  yellow = "\27[33m",
  blue = "\27[34m",
  magenta = "\27[35m",
  cyan = "\27[36m",
  white = "\27[37m",
}, {
  __index = function(_, key)
    error("invalid string-based color: " .. tostring(key))
  end,
})

M.bg_base_colors = setmetatable({
  black = "\27[40m",
  red = "\27[41m",
  green = "\27[42m",
  yellow = "\27[43m",
  blue = "\27[44m",
  magenta = "\27[45m",
  cyan = "\27[46m",
  white = "\27[47m",
}, {
  __index = function(_, key)
    error("invalid string-based color: " .. tostring(key))
  end,
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

M.default_colors = default_colors

-- Takes a color name/scheme by user and returns the ansi sequence for it.
-- This function takes three color types:
--
-- 1. base colors: black, red, green, yellow, blue, magenta, cyan, white. Use as `color("red")`.
-- 2. extended colors: a number between 0 and 255. Use as `color(123)`.
-- 3. RGB colors: three numbers between 0 and 255. Use as `color(123, 123, 123)`.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @tparam[opt] boolean fg true for foreground, false for background
-- @treturn string ansi sequence to write to the terminal
local function colorcode(r, g, b, fg)
  if type(r) == "string" then
    return fg and M.fg_base_colors[r] or M.bg_base_colors[r]
  end

  if type(r) ~= "number" or g < 0 or g > 255 then
    return "expected arg #1 to be a string or an integer 0-255, got " .. tostring(r) .. " (" .. type(r) .. ")"
  end
  if g == nil then
    return fg and "\27[38;5;" .. tostring(math.floor(r)) .. "m" or "\27[48;5;" .. tostring(math.floor(r)) .. "m"
  end

  if type(g) ~= "number" or g < 0 or g > 255 then
    return "expected arg #2 to be a number 0-255, got " .. tostring(g) .. " (" .. type(g) .. ")"
  end
  g = tostring(math.floor(g))

  if type(b) ~= "number" or b < 0 or b > 255 then
    return "expected arg #3 to be a number 0-255, got " .. tostring(g) .. " (" .. type(g) .. ")"
  end
  b = tostring(math.floor(b))

  return fg and "\27[38;2;" .. r .. ";" .. g .. ";" .. b .. "m" or "\27[48;2;" .. r .. ";" .. g .. ";" .. b .. "m"
end

M.colorcode = colorcode
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
function M.color_fgs(r, g, b)
  return colorcode(r, g, b, true)
end

--- Sets the foreground color and writes it to the terminal.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @return true
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
function M.color_bgs(r, g, b)
  return colorcode(r, g, b, false)
end

--- Sets the background color and writes it to the terminal.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @return true
function M.color_bg(r, g, b)
  output.write(M.color_bgs(r, g, b))
  return true
end

--- Creates an ansi sequence to set the underline attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
function M.underline_ons()
  return underline_on
end

--- Sets the underline attribute and writes it to the terminal.
-- @return true
function M.underline_on()
  output.write(M.underline_ons())
  return true
end

--- Creates an ansi sequence to unset the underline attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
function M.underline_offs()
  return underline_off
end

--- Unsets the underline attribute and writes it to the terminal.
-- @return true
function M.underline_off()
  output.write(M.underline_offs())
  return true
end

--- Creates an ansi sequence to set the blink attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
function M.blink_ons()
  return blink_on
end

--- Sets the blink attribute and writes it to the terminal.
-- @return true
function M.blink_on()
  output.write(M.blink_ons())
  return true
end

--- Creates an ansi sequence to unset the blink attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
function M.blink_offs()
  return blink_off
end

--- Unsets the blink attribute and writes it to the terminal.
-- @return true
function M.blink_off()
  output.write(M.blink_offs())
  return true
end

--- Creates an ansi sequence to set the reverse attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
function M.reverse_ons()
  return reverse_on
end

--- Sets the reverse attribute and writes it to the terminal.
-- @return true
function M.reverse_on()
  output.write(M.reverse_ons())
  return true
end

--- Creates an ansi sequence to unset the reverse attribute without writing it to the terminal.
-- @treturn string ansi sequence to write to the terminal
function M.reverse_offs()
  return reverse_off
end

--- Unsets the reverse attribute and writes it to the terminal.
-- @return true
function M.reverse_off()
  output.write(M.reverse_offs())
  return true
end


-- lookup brightness levels
local _brightness = setmetatable({
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
}, {
  __index = function(_, key)
    error("invalid brightness level: " .. tostring(key))
  end,
})

M.brightness = _brightness
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

M._brightness_sequence = _brightness_sequence

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

M._brightness_sequence_after_reset = _brightness_sequence_after_reset
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
function M.brightnesss(brightness)
  return _brightness_sequence[_brightness[brightness]]
end

--- Sets the brightness and writes it to the terminal.
-- @tparam string|integer brightness the brightness to set
-- @return true
function M.brightness(brightness)
  output.write(M.brightnesss(brightness))
  return true
end

return M