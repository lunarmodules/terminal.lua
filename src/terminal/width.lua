--- Module to check and validate character display widths.
-- Not all characters are displayed with the same width on the terminal.
-- The Unicode standard defines the width of many characters, but not all.
-- Especially the ['ambiguous width'](https://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt)
-- characters can be displayed with different
-- widths especially when used with East Asian languages.
--
-- This module provides functions to check the width of characters and strings.
-- This is done by writing them to the terminal and recording the change in
-- cursor position. The width is then stored in a cache, so subsequent calls
-- with the same character will be faster.
--
-- It is possible to preload the cache with the widths of a lot of characters at
-- once. This can be done with the `preload` function. This is preferred since it
-- is (a lot) faster than checking each character individually.

local M = {}
local char_widths = {} -- registry to keep track of already tested widths
local t = require "terminal"
local sys = require "system"


-- Test the width of a character by writing it to the terminal and measure cursor displacement.
-- No colors or cursor positioning/moving back is involved.
local function test_width_by_writing(char)
  local _, start_column = t.cursor_get()
  t.write(char)
  local _, end_column = t.cursor_get()
  if end_column < start_column then
    -- cursor wrapped to next line
    local _, cols = t.termsize()
    end_column = end_column + cols
  end
  local w = end_column - start_column
  char_widths[char] = w
  return w
end

--- Write a character and report its width in columns.
-- Writes a character to the terminal and returns its width in columns.
-- The width measured is recorded in the cache, so subsequent calls with the
-- same character will be faster.
-- @tparam string|number char the character to write, a single utf8 character, or codepoint
-- @treturn number the width of the character in columns
function M.write_cwidth(char)
  if type(char) == "number" then
    char = utf8.char(char)
  end

  local w = char_widths[char]
  if w then
    -- we have a cached width
    t.write(char)
    return w
  end

  return test_width_by_writing(char)
end

--- Write a string and report its width in columns.
-- Writes a string to the terminal and returns its width in columns.
-- The width measured for each character is recorded in the cache.
-- @tparam string str the string to write
-- @treturn number the width of the string in columns
function M.write_swidth(str)
  local w = 0
  for pos, char in utf8.codes(str) do
    w = w + M.write_cwidth(utf8.char(char))
  end
  return w
end

--- Reports the width of a character in columns.
-- Same as `write_cwidth`, but writes it "invisible" (brightness = 0), so it
-- does not show. The cursor is returned to its original position.
-- It will however overwrite existing content, and might locally
-- change the background color. So set that accordingly to avoid unwanted effects.
-- The width measured is recorded in the cache, so subsequent calls with the
-- same character will be faster.
-- @tparam string|number char the character to test, a single utf8 character, or codepoint
-- @treturn number the width of the character in columns
function M.get_cwidth(char)
  if type(char) == "number" then
    char = utf8.char(char)
  end

  local w = char_widths[char]
  if w then
    return w
  end

  t.textpush({ brightness = 0 })
  local w = test_width_by_writing(char)
  t.textpop()
  t.cursor_left(w)
  return w
end

--- Reports the width of a string in columns. Each character will be tested and
-- the width recorded in the cache. This can be used to pre-load the cache with
-- the widths of a string, without actually showing it on the terminal.
-- Same as `write_swidth`, but uses `get_cwidth` so it will not really show on
-- the terminal. The cursor is returned to its original position.
-- @tparam string str the string to test
-- @treturn number the width of the string in columns
function M.get_swidth(str)
  local w = 0
  for pos, codepoint in utf8.codes(str) do
    w = w + M.get_cwidth(utf8.char(codepoint))
  end
  return w
end

--- Returns the width of a character in columns, matches `sys.utf8cwidth`.
-- This will check the cache of recorded widths first, and if not found,
-- use `sys.utf8cwidth` to determine the width.
-- @tparam string|number char the character (string or codepoint) to check
-- @treturn number the width of the first character in columns
function M.utf8cwidth(char)
  if type(char) == "string" then
    char = utf8.codepoint(char)
  elseif type(char) ~= "number" then
    error("expected string or number, got " .. type(char), 2)
  end
  return char_widths[utf8.char(char)] or sys.utf8cwidth(char)
end

--- Returns the width of a string in columns, matches `sys.utf8swidth`.
-- It will use `utf8cwidth` to determine the width of each character, and as such
-- will use the cached widths created with `written_width` and `get_width`.
-- @tparam string str the string to check
-- @treturn number the width of the string in columns
function M.utf8swidth(str)
  local w = 0
  for pos, char in utf8.codes(str) do
    w = w + M.utf8cwidth(char)
  end
  return w
end

--- Preload the cache with the widths of all characters in the string.
-- Characters will be written 'invisible', so it does not show on the terminal.
-- It will read many character-widths at once, and hence is a lot faster than checking
-- each character individually.
-- @tparam string str the string of characters to preload
-- @treturn[1] boolean true if successful
-- @treturn[2] nil
-- @treturn[2] string error message
function M.preload(str)
  local size = 50 -- max number of characters to do in 1 terminal write
  local test = {}
  local dup = {}
  for pos, char in utf8.codes(str) do
    char = utf8.char(char) -- convert back to utf8 string
    if not (char_widths[char] or dup[char]) then
      test[#test+1] = char
      dup[char] = true
    end
  end

  if #test == 0 then
    return -- nothing to test
  end

  t.textpush({ brightness = 0 }) -- set color to "hidden"

  local r, c = t.cursor_get() -- retrieve current position
  local setpos = t.cursor_sets(r, c) -- string to restore cursor to current position
  local getpos = t.cursor_get_querys() -- string to inject query for current position
  local chunk = {}
  local chars = {}
  for i = 1, #test do -- process in chunks of max size
    chars[#chars+1] = test[i]
    local s = test[i] -- the character
              .. getpos -- query for new position
              .. setpos -- restore cursor to current position
    chunk[#chunk+1] = s
    if #chunk == size or i == #test then
      -- handle the chunk
      t.write(table.concat(chunk))
      local positions, err = t.input.read_cursor_pos(#chunk)
      if not positions then
        t.textpop() -- restore color (drop hidden)
        return nil, err
      end

      -- record sizes reported
      for j, pos in ipairs(positions) do
        local w = pos[2] - c
        if w < 0 then
          -- cursor wrapped to next line
          local _, cols = t.termsize()
          w = w + cols
        end
        char_widths[chars[j]] = w
      end

      chunk = {} -- clear for next chunk
      chars = {}
    end
  end

  t.textpop() -- restore color (drop hidden)
  return true
end

return M
