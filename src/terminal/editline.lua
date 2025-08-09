--- UTF8 based EditLine class.
--
-- This class handles a UTF8 string with editing, formatting (word-wrap), cursor tracking, and width tracking.
--
-- *Example:*
--
--     local EditLine = require("terminal.editline")
--     local line = EditLine {
--       value = "héllo界",
--       position = 6,                                  -- cursor after 'o', on '界'
--     }
--
--     print(line)                                      -- Output: héllo界
--     print("Characters:", line:len_char())            -- Output: Characters: 6
--     print("Columns:", line:len_col())                -- Output: Columns: 7 (since '界' is width 2)
--
--     -- Move the cursor
--     line:left(2)
--     print("Cursor char position:", line:pos_char())  -- Output: 4
--     print("Cursor column position:", line:pos_col()) -- Output: 4
--
--     -- Editing
--     line:insert("!")
--     print(line)                                      -- Output: hél!lo界
-- @classmod EditLine

local width = require("terminal.text.width")
local utf8 = require("utf8") -- explicit lua-utf8 library call, for <= Lua 5.3 compatibility
local utils = require("terminal.utils")



-- Constants for width representation
local SINGLE_WIDTH = " "
local DOUBLE_WIDTH = "  "

--- Default word delimiters for EditLine.
local WORD_DELIMITERS = [[/\()"'-.,:;<>~!@#$%^&*|+=[]{}~?│ ]] .. "\t"



-- Create base class for EditLine
local EditLine = utils.class()

function EditLine:__tostring()
  return table.concat(self.chars)
end



-- Check if a character at a given index is a word delimiter.
local function is_delimiter(self, idx)
  return self.word_delimiters[self.chars[idx] or ""] == true
end



--- Create a new EditLine instance.
-- Do not call this method directly, call on the class instead, see the example.
-- @tparam[opt={}] table|string opts Options for the edit line, or a string value to initialize.
-- @tparam[opt=""] string opts.value Initial value for the edit line.
-- @tparam[opt] string opts.word_delimiters Word delimiters for word operations.
-- @tparam[opt] number opts.position Initial cursor position (defaults to the end).
-- @treturn EditLine A new EditLine instance.
-- @usage
-- local EditLine = require("terminal.editline")
-- local line = EditLine {
--   value = "Hello, world!",
--   position = 1,
-- }
function EditLine:init(opts)
  if opts == nil or type(opts) == "string" then
    opts = { value = opts or "" }
  end

  self.chars = {}   -- array of utf8 characters (strings)
  self.widths = {}  -- array of width strings (SINGLE_WIDTH or DOUBLE_WIDTH)
  self.cursor_idx = 1  -- cursor position (1-based, between 1 and #chars+1)
  self.cursor_col = 1  -- cursor column position (1-based)

  self.word_delimiters = {}
  for _, c in utf8.codes(opts.word_delimiters or WORD_DELIMITERS) do
    self.word_delimiters[utf8.char(c)] = true
  end

  self:insert(opts.value)

  if opts.position then
    self:goto_index(opts.position)
  end
end



--- Returns the current cursor position (chars).
-- @treturn number the current cursor position in UTF8 characters.
function EditLine:pos_char()
  return self.cursor_idx
end



--- Returns the current cursor position (columns).
-- @treturn number the current cursor position in display columns
function EditLine:pos_col()
  return self.cursor_col
end



--- Returns the current length (chars).
-- @treturn number the current length in UTF8 characters
function EditLine:len_char()
  return #self.chars
end



--- Returns the current length (columns).
-- @treturn number the current length in display columns
function EditLine:len_col()
  return #(table.concat(self.widths))
end



--- Inserts a unicode codepoint at the current cursor position.
-- @tparam number cp the codepoint to insert
-- @return self (for chaining)
function EditLine:insert_cp(cp)
  local ch = utf8.char(cp)
  local w = width.utf8cwidth(cp)

  table.insert(self.chars, self.cursor_idx, ch)
  table.insert(self.widths, self.cursor_idx, (w == 2) and DOUBLE_WIDTH or SINGLE_WIDTH)
  self.cursor_idx = self.cursor_idx + 1
  self.cursor_col = self.cursor_col + w
  return self
end



--- Inserts a string at the current cursor position.
-- @tparam string s the string to insert
-- @return self (for chaining)
function EditLine:insert(s)
  for _, cp in utf8.codes(s or "") do
    self:insert_cp(cp)
  end
  return self
end



--- Moves the cursor to the left.
-- This function moves the cursor left by `n` characters. It will not move the cursor
-- past the start of the string (no error will be raised).
-- @tparam[opt=1] number n the number of characters to move left
-- @return self (for chaining)
function EditLine:left(n)
  for _ = 1, n or 1 do
    if self.cursor_idx <= 1 then
      return self
    end

    self.cursor_idx = self.cursor_idx - 1

    local w = self.widths[self.cursor_idx] == SINGLE_WIDTH and 1 or 2
    self.cursor_col = self.cursor_col - w
  end

  return self
end



--- Moves the cursor to the right.
-- This function moves the cursor right by `n` characters. It will not move the cursor
-- past the end of the string (no error will be raised).
-- @tparam[opt=1] number n the number of characters to move right
-- @return self (for chaining)
function EditLine:right(n)
  for _ = 1, n or 1 do
    if self.cursor_idx > #self.chars then
      return self
    end

    local w = self.widths[self.cursor_idx] == SINGLE_WIDTH and 1 or 2
    self.cursor_col = self.cursor_col + w
    self.cursor_idx = self.cursor_idx + 1
  end

  return self
end



--- Deletes the character left of the current cursor position.
-- If/once the cursor is at the start of the string, it does nothing.
-- @tparam[opt=1] number n the number of characters to delete
-- @return self (for chaining)
function EditLine:backspace(n)
  if self.cursor_idx <= 1 then
    return self
  end

  n = n or 1
  n = math.min(n, self.cursor_idx - 1)

  return self:left(n):delete(n)
end



--- Deletes the character at the current cursor position.
-- If/once the cursor is at the end of the string, it does nothing.
-- @tparam[opt=1] number n the number of characters to delete
-- @return self (for chaining)
function EditLine:delete(n)
  local idx = self.cursor_idx
  for _ = 1, n or 1 do
    if idx > #self.chars then
      return self
    end

    table.remove(self.chars, idx)
    table.remove(self.widths, idx)
  end

  return self
end



--- Moves the cursor to the start of the string.
-- @return self (for chaining)
function EditLine:goto_home()
  self.cursor_idx = 1
  self.cursor_col = 1
  return self
end



--- Moves the cursor to the end of the string.
-- @return self (for chaining)
function EditLine:goto_end()
  self.cursor_idx = #self.chars + 1
  self.cursor_col = self:len_col() + 1
  return self
end



--- Moves the cursor to the position given by the index.
-- Cursor position indexes range from 1 to `len + 1`, where `len` is the length of the string in characters.
-- Negative indexes are counted from the end backwards, so `-1` is the same as `goto_end`.
-- If the index is out of bounds, it will move the cursor to the closest valid position.
-- @tparam number pos the position (in characters) to move the cursor to (0-based index)
-- @return self (for chaining)
function EditLine:goto_index(pos)
  pos = utils.resolve_index(pos, #self.chars + 1, 1)
  self:goto_home():right(pos - 1)
  return self
end



--- Clears the input.
-- @return self (for chaining)
function EditLine:clear()
  self.chars = {}
  self.widths = {}
  self.cursor_idx = 1
  self.cursor_col = 1
  return self
end



--- Replaces the current input with a new string.
-- This function clears the current input and inserts the new string at the end.
-- The cursor will be at the end of the new string.
-- @tparam string s the new string to insert
-- @return self (for chaining)
function EditLine:replace(s)
  return self:clear():insert(s)
end



--- Deletes all characters to the left of the current cursor position.
-- @return self (for chaining)
function EditLine:backspace_to_start()
  if self.cursor_idx <= 1 then
    return self
  end

  local n = self.cursor_idx - 1

  return self:goto_home():delete(n)
end



--- Deletes all characters to the right of the current cursor position.
-- @return self (for chaining)
function EditLine:delete_to_end()
  local c = self.chars
  local w = self.widths
  for i = self.cursor_idx, #self.chars do
    c[i] = nil
    w[i] = nil
  end

  return self
end



--- Moves the cursor to the start of the current word. If already at start, moves to the start of the previous word.
-- This function moves the cursor left until it reaches the start of the previous word.
-- Words are defined by non-delimiter characters.
-- @tparam[opt=1] number n the number of words to move left
-- @return self (for chaining)
function EditLine:left_word(n)
  for _ = 1, n or 1 do
    -- skip over any delimiters to the left
    while self.cursor_idx > 1 do
      if not is_delimiter(self, self.cursor_idx - 1) then
        break
      end
      self:left()
    end

    -- move left to the start of the word
    while self.cursor_idx > 1 do
      if is_delimiter(self, self.cursor_idx - 1) then
        break
      end
      self:left()
    end
  end

  return self
end



--- Moves the cursor to the start of the next word.
-- This function moves the cursor right until it reaches the start of the next word.
-- Words are defined by non-delimiter characters.
-- @tparam[opt=1] number n the number of words to move left
-- @return self (for chaining)
function EditLine:right_word(n)
  local len = #self.chars
  for _ = 1, n or 1 do
    -- skip over any characters to the right
    while self.cursor_idx <= len do
      if is_delimiter(self, self.cursor_idx) then
        break
      end
      self:right()
    end

    -- skip over any delimiters to the right
    while self.cursor_idx <= len do
      if not is_delimiter(self, self.cursor_idx) then
        break
      end
      self:right()
    end
  end

  return self
end



--- Backspace until the start of the current word. If at the start, backspace to the start of the previous word.
-- Words are defined by non-delimiter characters.
-- @tparam[opt=1] number n the number of words to move left
-- @return self (for chaining)
function EditLine:backspace_word(n)
  local idx = self.cursor_idx
  return self:left_word(n):delete(idx - self.cursor_idx)
end



--- Delete until the end of the current word.
-- Words are defined by non-delimiter characters.
-- @tparam[opt=1] number n the number of words to move left
-- @return self (for chaining)
function EditLine:delete_word(n)
  for _ = 1, n or 1 do
    while self.cursor_idx <= #self.chars do
      if not is_delimiter(self, self.cursor_idx) then break end
      self:delete()
    end
    while self.cursor_idx <= #self.chars do
      if is_delimiter(self, self.cursor_idx) then break end
      self:delete()
    end
  end
  return self
end



--- Returns a new Editline object being a substring.
-- This operates based on characters.
-- Negative indexes are counted from the end, so `-1` is the last character.
-- @tparam[opt=1] number i Start index.
-- @tparam[opt=-1] number j End index.
-- @treturn EditLine A new EditLine instance containing the substring.
function EditLine:sub_char(i, j)
  assert(i, "expected argument #1 to be a number")
  i = utils.resolve_index(i, #self.chars, 1)
  j = utils.resolve_index(j or -1, #self.chars, 1)
  return EditLine(table.concat(self.chars, "", i, j))
end



do
  -- This function is used to get a non-wrapped line of text.
  -- From current cursor position(inclusive) to the target size in columns.
  -- Cursor will be moved to first character after the selected line.
  -- @tparam EditLine self The EditLine instance.
  -- @tparam number target_size The target size for the line (minimum 2).
  -- @return EditLine The line of text up to the target size.
  -- @return number The size of the returned line in columns.
  local function get_non_wrapped_line(self, target_size)
    assert(target_size > 1, "target_size must be 2 or greater") -- must be able to hold at least 1 double width character
    local size = 0
    local start = self.cursor_idx
    while true do
      if self.cursor_idx > #self.chars then
        break -- no more chars to add
      end
      local w = self.widths[self.cursor_idx] == SINGLE_WIDTH and 1 or 2
      if size + w > target_size then
        break -- double-width character doesn't fit
      end
      -- add next character
      size = size + w
      self:right()
      if size >= target_size then
        break -- reached target size
      end
    end

    if size == 0 then
      return EditLine(""), 0 -- no characters selected
    end
    return self:sub_char(start, self.cursor_idx - 1), size
  end
  if _G._TEST then -- export only when testing
    EditLine._get_non_wrapped_line = get_non_wrapped_line
  end


  -- This function is used to get a word-wrapped line of text.
  -- From current cursor position(inclusive) to the target size in columns.
  -- Cursor will be moved to first character after the selected line.
  -- @tparam EditLine self The EditLine instance.
  -- @tparam number target_size The target size for the line (minimum 2).
  -- @return EditLine The line of text up to the target size.
  -- @return number The size of the returned line in columns.
  local function get_wrapped_line(self, target_size)
    local line, size = get_non_wrapped_line(self, target_size)
    if (not line) -- there was an error
       or self.cursor_idx > #self.chars -- we have the full length, no need to wrap
       or self.word_delimiters[line.chars[line.cursor_idx - 1]] -- last char is delimiter
       then
      -- print("result:",tostring(line), "\n")
      return line, size
    end
    -- print("non-wrapped:", "'"..tostring(line).."'")

    -- find last word-delimiter char, walk back from the end
    local idx = line.cursor_idx - 1 -- cursor was behind line, so subtract one
    local drop = 0 -- chars to drop
    local dropw = 0 -- width to drop
    while idx ~= 0 and not self.word_delimiters[line.chars[idx]] do
      -- print("dropping:", "'"..tostring(line.chars[idx]).."'")
      drop = drop + 1
      dropw = dropw + (line.widths[idx] == SINGLE_WIDTH and 1 or 2)
      idx = idx - 1
    end

    if idx == 0 then
      -- we dropped the whole line, so word is longer than the width, cannot wrap
      return line, size
    end

    if drop ~= 0 then
      -- reduce size to last delimiter
      self:left(drop) -- move cursor to new end position
      line:backspace(drop) -- drop chars from line
      size = size - dropw
    end

    -- print("result:",tostring(line), "\n")
    return line, size
  end
  if _G._TEST then -- export only when testing
    EditLine._get_wrapped_line = get_wrapped_line
  end


  -- This function is used to pad an Editline object to a number of columns.
  -- The pad character will be " " (space).
  -- Cursor will stay at the same position.
  -- @tparam EditLine self The EditLine instance.
  -- @tparam number current_width The current width in columns of the Editline.
  -- @tparam number required_width The requested width in columns.
  local function pad_line(self, current_width, required_width)
    local pad = required_width - current_width

    -- capture and restore position
    local old_cursor_idx = self.cursor_idx
    local old_cursor_col = self.cursor_col
    self:goto_end():insert((" "):rep(pad))
    self.cursor_idx = old_cursor_idx
    self.cursor_col = old_cursor_col
  end
  if _G._TEST then -- export only when testing
    EditLine._pad_line = pad_line
  end


  --- Format the contents for display, over multiple lines if necessary.
  -- The return table contains an array of `Editline` objects.
  -- Each entry will have its cursor position set at the end, except for the entry that
  -- actually has the cursor which will have the cursor position at the same character
  -- as the input position.
  -- If padding is used, the cursor will be placed before any padding.
  -- @tparam[opt] table opts Options for formatting.
  -- @tparam[opt=80] number opts.width The maximum width (in columns) of each line.
  -- @tparam[opt=width] number opts.first_width The width of the first line (in case of prompts/labels).
  -- @tparam[opt=true] boolean opts.wordwrap Whether to wrap words that exceed the width.
  -- @tparam[opt=true] boolean opts.pad Whether to pad the lines to the full width.
  -- @tparam[opt=pad] boolean opts.pad_last Whether to pad the last line.
  -- @tparam[opt=false] boolean opts.no_new_cursor_line If true, no empty new line will be added if the last line exactly fits the width.
  -- @treturn[1] table A table containing the individual `Editline` objects.
  -- @treturn[1] number the cursor position row
  -- @treturn[1] number the cursor position column
  function EditLine:format(opts)
    opts = opts or {}
    local width = opts.width or 80
    assert(width > 0, "Width must be greater than 0")
    local first_width = opts.first_width or width
    assert(first_width > 0, "First width must be greater than 0")
    local wordwrap = opts.wordwrap ~= false
    local pad = opts.pad ~= false
    local pad_last
    if opts.pad_last == nil then
      pad_last = pad
    else
      pad_last = not not opts.pad_last
    end
    local no_new_cursor_line = not not opts.no_new_cursor_line

    local wrapper = wordwrap and get_wrapped_line or get_non_wrapped_line

    -- save cursor position before walking the string
    local old_cursor_idx = self.cursor_idx
    local old_cursor_col = self.cursor_col

    -- split into lines
    local lines = {}
    local line_cols = {}
    local target_size = first_width
    local cur_track = old_cursor_idx
    local cur_line, cur_col
    self:goto_home()

    local size = #self.chars
    while self.cursor_idx < size do
      local line, cols = wrapper(self, target_size)
-- print("line:", "'"..tostring(line).."'", cols)
      lines[#lines + 1] = line
      line_cols[#line_cols + 1] = cols

      local l = line:len_char()
      if l >= cur_track then
        -- cursor is on this line
-- print "cursor is on this line"
        cur_line = #lines
        line:goto_index(cur_track)
        cur_col = line:pos_col()
        if cur_line == 1 then
          -- add offset if on line 1
          cur_col = cur_col + (width - first_width)
        end
        cur_track = math.huge -- ensure we're not running this again
      else
        cur_track = cur_track - l
      end

      target_size = width -- update target size after first-line
    end

    -- add extra line holding cursor, if cursor is at the end of the last line at exact length
    -- (so the cursor is beyond the width set, and is the only thing on the next line)
    if cur_line == nil then
      if no_new_cursor_line then
        -- no new line, so cursor is at the end of the last line, beyond the width
        cur_line = #lines
        cur_col = width + 1
      else
        -- add an empty new line just to hold the cursor
        cur_line = #lines + 1
        lines[cur_line] = EditLine("")
        cur_col = 1
      end
    end

    -- add padding if required
    if #lines == 1 then
      -- single line, so first and last is the same
      if pad_last then
        pad_line(lines[1], line_cols[1], first_width)
      end
    else
      if pad then
        local target_width = first_width
        for i = 1, #lines -1 do
          pad_line(lines[i], line_cols[i], target_width)
          target_width = width -- update tager after first line handling
        end
      end
      if pad_last then
        local count = #lines
        pad_line(lines[count], line_cols[count], width)
      end
    end

    -- restore cursor position
    self.cursor_idx = old_cursor_idx
    self.cursor_col = old_cursor_col

    return lines, cur_line, cur_col
  end
end


return EditLine
