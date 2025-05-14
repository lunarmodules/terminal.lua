--- Module to check and validate character display widths.
-- Not all characters are displayed with the same width on the terminal.
-- The Unicode standard defines the width of many characters, but not all.
-- Especially the ['ambiguous width'](https://www.unicode.org/Public/UCD/latest/ucd/EastAsianWidth.txt)
-- characters can be displayed with different
-- widths especially when used with East Asian languages.
-- The only way to truly know their display width is to write them to the terminal
-- and measure the cursor position change.
--
-- This module implements a cache of character widths as they have been measured.
--
-- To populate the cache with tested widths use `test` and `test_write`.
--
-- To check width, using the cached widths, use `utf8cwidth` and `utf8swidth`. Any
-- character not in the cache will be passed to `system.utf8cwidth` to determine the width.
-- @module terminal.text.width

local M = {}
package.loaded["terminal.text.width"] = M -- Register the module early to avoid circular dependencies

local t = require "terminal"
local sys = require "system"
local sys_utf8cwidth = sys.utf8cwidth



local char_widths = {} -- registry to keep track of already tested widths



--- Returns the width of a character in columns, matches `system.utf8cwidth` signature.
-- This will check the cache of recorded widths first, and if not found,
-- use `system.utf8cwidth` to determine the width. It will not test the width.
-- @tparam string|number char the character (string or codepoint) to check
-- @treturn number the width of the first character in columns
function M.utf8cwidth(char)
  if type(char) == "string" then
    char = utf8.codepoint(char)
  elseif type(char) ~= "number" then
    error("expected string or number, got " .. type(char), 2)
  end
  return char_widths[utf8.char(char)] or sys_utf8cwidth(char)
end



--- Returns the width of a string in columns, matches `system.utf8swidth` signature.
-- It will use the cached widths, if no cached width is available it falls back on `system.utf8cwidth`.
-- It will not test the width.
-- @tparam string str the string to check
-- @treturn number the width of the string in columns
function M.utf8swidth(str)
  local w = 0
  for pos, char in utf8.codes(str) do
    w = w + (char_widths[utf8.char(char)] or sys_utf8cwidth(char))
  end
  return w
end



--- Returns the width of the string, by test writing.
-- Characters will be written 'invisible', so it does not show on the terminal, but it does need
-- room to print them. The cursor is returned to its original position.
-- It will read many character-widths at once, and hence is a lot faster than checking
-- each character individually. The width of each character measured is recorded in the cache.
--
-- - the text stack is used to set the brightness to 0 before, and restore colors/attributes after the test.
-- - the test will be done at the current cursor position, and hence content there might be overwritten. Since
--   a character is either 1 or 2 columns wide. The content of those 2 columns might have to be restored.
-- @tparam string str the string of characters to test
-- @treturn[1] number width in columns of the string
-- @treturn[2] nil
-- @treturn[2] string error message
-- @within Testing
function M.test(str)
  local size = 50 -- max number of characters to do in 1 terminal write
  local test = {}
  local dup = {}
  local width = 0
  for pos, char in utf8.codes(str) do
    char = utf8.char(char) -- convert back to utf8 string
    local cw = char_widths[char]
    if cw then
      -- we already know the width
      width = width + cw
    elseif not dup[char] then
      -- we have no width, and it is not yet in the test list, so add it
      test[#test+1] = char
      dup[char] = true
    end
  end

  if #test == 0 then
    return width -- nothing to test, return the width
  end

  t.text.stack.push({ brightness = 0 }) -- set color to "hidden"

  local r, c = t.cursor.position.get() -- retrieve current position
  local setpos = t.cursor.position.set_seq(r, c) -- string to restore cursor to current position
  local getpos = t.cursor.position.query_seq() -- string to inject query for current position
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
      t.output.write(table.concat(chunk) .. "  " .. setpos) -- write the chunk
      local positions, err = t.input.read_query_answer("^\27%[(%d+);(%d+)R$", #chunk)
      if not positions then
        t.text.stack.pop() -- restore color (drop hidden)
        return nil, err
      end

      -- record sizes reported
      for j, pos in ipairs(positions) do
        local w = pos[2] - c
        if w < 0 then
          -- cursor wrapped to next line
          local _, cols = t.size()
          w = w + cols
        end
        char_widths[chars[j]] = w
      end

      chunk = {} -- clear for next chunk
      chars = {}
    end
  end

  t.text.stack.pop() -- restore color (drop hidden)
  return M.test(str) -- re-run to get the total width, since all widths are known now
end



--- Returns the width of the string, and writes it to the terminal.
-- Writes the string to the terminal, visible, whilst at the same time injecting cursor-position queries
-- to detect the width of the unknown characters in the string.
-- It will read many character-widths at once, and hence is a lot faster than checking
-- each character individually.
-- The width of each character measured is recorded in the cache.
-- @tparam string str the string of characters to write and test
-- @treturn number the width of the string in columns
-- @within Testing
function M.test_write(str)
  local chunk = {} -- every character, pre/post fixed with a query if needed
  local chars = {} -- array chars to test
  local width = 0

  do -- parse the string to test
    local getpos = t.cursor.position.query_seq() -- string to inject; query for current position
    local dups = {}

    for pos, char in utf8.codes(str) do
      char = utf8.char(char) -- convert back to utf8 string
      local cw = char_widths[char]
      local query = ""
      if cw then
        -- we already know the width
        width = width + cw
      elseif not dups[char] then
        -- we have no width, and it is not yet in the test list, so add the query
        query = getpos
        chars[#chars+1] = char
        dups[char] = true
      end
      chunk[#chunk+1] = query .. char .. query
    end
  end

  t.output.write(table.concat(chunk))
  if #chars == 0 then
    return width -- nothing to test, return the width
  end

  local positions, err = t.input.read_query_answer("^\27%[(%d+);(%d+)R$", #chars * 2)
  if not positions then
    return nil, err
  end

  -- record sizes reported
  for j, pos in ipairs(positions) do
    local char = chars[j]
    local col_start = pos[j*2 - 1][2]
    local col_end = pos[j*2][2]
    local w = col_end - col_start
    if w < 0 then
      -- cursor wrapped to next line
      local _, cols = t.size()
      w = w + cols
    end
    char_widths[char] = w
  end

  -- re-run to get the total width, since all widths are known now,
  -- but this time do not write the string, just return the width
  return M.test(str)
end


--- Like string:sub(), Returns the substring of the string that starts from i and go until j inclusive, but operators on utf8 characters
--- Preserves utf8.len()
-- @tparam string str the string to take the substring of
-- @tparam number i the starting index of the substring
-- @tparam number j the ending index of the substring
-- @treturn string the substring
function M.utf8sub(str, i, j)
  local n = utf8.len(str)
  if #str == n then
    return str:sub(i, j)
  end
  i = i or 1
  j = j or -1
  i = ((i - (i >= 0 and 1 or 0)) % n) + 1
  j = ((j - (j >= 0 and 1 or 0)) % n) + 1
  if j < i then
    return ""
  end
  local indices = {}
  for pos, _ in utf8.codes(str) do
    indices[#indices + 1] = pos
  end
  indices[#indices + 1] = #str + 1
  return str:sub(indices[i], indices[j + 1] - 1)
end

return M
