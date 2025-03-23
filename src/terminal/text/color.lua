--- Terminal text color module.
-- Provides utilities to set text color in terminals.
-- @module terminal.text.color
local M = {}
package.loaded["terminal.text.color"] = M -- Register the module early to avoid circular dependencies

local output = require("terminal.output")
local utils = require("terminal.utils")




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
function M.fores(r, g, b)
  return colorcode(r, g, b, true)
end



--- Sets the foreground color and writes it to the terminal.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @return true
function M.fore(r, g, b)
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
function M.backs(r, g, b)
  return colorcode(r, g, b, false)
end



--- Sets the background color and writes it to the terminal.
-- @tparam integer r in case of RGB, the red value, a number for extended colors, a string color for base-colors
-- @tparam[opt] number g in case of RGB, the green value
-- @tparam[opt] number b in case of RGB, the blue value
-- @return true
function M.back(r, g, b)
  output.write(M.color_bgs(r, g, b))
  return true
end



return M
