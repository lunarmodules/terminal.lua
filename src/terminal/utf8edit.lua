--- UTF8 based editline class.
--
-- This class handles a UTF8 string with editing operations, and cursor and width tracking.
--
-- @classmod Utf8edit
-- @usage
-- local Utf8edit = require("terminal.utf8edit")
-- local line = Utf8edit("héllo界")
--
-- print(line)                                      -- Output: héllo界
-- print("Characters:", line:len_char())            -- Output: Characters: 6
-- print("Columns:", line:len_col())                -- Output: Columns: 7 (since '界' is width 2)
--
-- -- Move the cursor
-- line:left(2)
-- print("Cursor char position:", line:pos_char())  -- Output: 4
-- print("Cursor column position:", line:pos_col()) -- Output: 4
--
-- -- Editing
-- line:insert("!")
-- print(line)                                      -- Output: héll!o界

local utils = require("terminal.utils")
local width = require("terminal.text.width")
local utf8 = require("utf8") -- explicit lua-utf8 library call, for <= Lua 5.3 compatibility

local UTF8EditLine = utils.class()


function UTF8EditLine:__tostring()
  local head = self.head
  local res = {}
  while head do
    res[#res + 1] = head.value or ""
    head = head.next
  end
  return table.concat(res)
end

--- A list of word delimiters for word-wise navigation
-- @string default_word_delimiters
UTF8EditLine.default_word_delimiters = [[/\()"'-.,:;<>~!@#$%^&*|+=[]{}~?│ ]]

-- Checks if the current character is a word delimiter.
-- @tparam table node the node to check
-- @treturn boolean true if the character is a word delimiter, false otherwise
local function is_delimiter(self, node)
  local char = node.value or ""
  return self.word_delimiters[char] == true
end



--- Creates a new `utf8edit` instance. This method is invoked by calling on the class.
-- The cursor position will be at the end of the string.
-- @tparam[opt=""] string s the UTF8 string to parse
-- @return new editline object
-- @usage
-- local Utf8edit = require("terminal.utf8edit")
-- local newLineObj = Utf8edit("héllo界")
function UTF8EditLine:init(opts)
  self.icursor = {}          -- tracking the cursor internally (utf8 characters)
  self.ocursor = 1           -- tracking the cursor externally (columns)
  self.ilen = 0              -- tracking the length internally (# of utf8 characters)
  self.olen = 0              -- tracking the length externally (# of displayed columns)
  self.head = {}             -- start of the list
  self.tail = self.icursor   -- prepare linked list
  self.tail.prev = self.head
  self.head.next = self.tail

  if opts == nil or type(opts) == "string" then
    opts = { value = opts or ""}
  end

  self:insert(opts.value) -- inserts the value

  if opts.position then
    self:goto_index(opts.position) -- move the cursor to the inital position
  end

  self.word_delimiters = {} -- set the word delimiters
  for _, c in utf8.codes(opts.word_delimiters or UTF8EditLine.default_word_delimiters) do
    self.word_delimiters[utf8.char(c)] = true
  end

end



--- Returns the current cursor position (chars).
-- @treturn number the current cursor position in UTF8 characters.
function UTF8EditLine:pos_char()
  local l = 0
  local head = self.head
  while head do
    if head == self.icursor then
      return l
    end
    l = l + 1
    head = head.next
  end
  return l
end



--- Returns the current cursor position (columns).
-- @treturn number the current cursor position in display columns
function UTF8EditLine:pos_col()
  return self.ocursor
end



--- Returns the current length (chars).
-- @treturn number the current length in UTF8 characters
function UTF8EditLine:len_char()
  return self.ilen
end



--- Returns the current length (columns).
-- @treturn number the current length in display columns
function UTF8EditLine:len_col()
  return self.olen
end



--- Inserts a unicode codepoint at the current cursor position.
-- @tparam number cp the codepoint to insert
-- @return self (for chaining)
function UTF8EditLine:insert_cp(cp)
  local node = { value = utf8.char(cp), next = self.icursor, prev = self.icursor.prev }
  self.icursor.prev.next = node
  self.icursor.prev = node
  self.ilen = self.ilen + 1
  self.olen = self.olen + width.utf8cwidth(cp)
  self.ocursor = self.ocursor + width.utf8cwidth(cp)
  return self
end



--- Inserts a string at the current cursor position.
-- @tparam string s the string to insert
-- @return self (for chaining)
function UTF8EditLine:insert(s)
  for _, cp in utf8.codes(s or "") do
    self:insert_cp(cp)
  end
  return self
end



--- Deletes the character left of the current cursor position.
-- If/once the cursor is at the start of the string, it does nothing.
-- @tparam[opt=1] number n the number of characters to delete
-- @return self (for chaining)
function UTF8EditLine:backspace(n)
  for _ = 1, n or 1 do
    if self.icursor.prev == self.head then
      return self
    end
    local prev = self.icursor.prev.prev or self.head
    local next = self.icursor
    local c = self.icursor.prev.value
    prev.next = next
    next.prev = prev
    self.ilen = self.ilen - 1
    self.olen = self.olen - width.utf8cwidth(c)
    self.ocursor = self.ocursor - width.utf8cwidth(c)
  end
  return self
end



--- Moves the cursor to the left.
-- This function moves the cursor left by `n` characters. It will not move the cursor
-- past the start of the string (no error will be raised).
-- @tparam[opt=1] number n the number of characters to move left
-- @return self (for chaining)
function UTF8EditLine:left(n)
  for _ = 1, n or 1 do
    if self.icursor.prev == self.head then
      return self
    end
    self.icursor = self.icursor.prev
    self.ocursor = self.ocursor - (self.icursor.value and width.utf8cwidth(self.icursor.value) or 1)
  end
  return self
end



--- Moves the cursor to the right.
-- This function moves the cursor right by `n` characters. It will not move the cursor
-- past the end of the string (no error will be raised).
-- @tparam[opt=1] number n the number of characters to move right
-- @return self (for chaining)
function UTF8EditLine:right(n)
  for _ = 1, n or 1 do
    if self.icursor == self.tail then
      return self
    end
    self.ocursor = self.ocursor + (self.icursor.value and width.utf8cwidth(self.icursor.value) or 1)
    self.icursor = self.icursor.next
  end
  return self
end



--- Deletes the character at the current cursor position.
-- If/once the cursor is at the end of the string, it does nothing.
-- @tparam[opt=1] number n the number of characters to delete
-- @return self (for chaining)
function UTF8EditLine:delete(n)
  for _ = 1, n or 1 do
    if self.icursor == self.tail then
      return self
    end
    self:right():backspace()
  end
  return self
end



--- Moves the cursor to the start of the string.
-- @return self (for chaining)
function UTF8EditLine:goto_home()
  self.icursor = self.head.next
  self.ocursor = 1
  return self
end



--- Moves the cursor to the end of the string.
-- @return self (for chaining)
function UTF8EditLine:goto_end()
  self.icursor = self.tail
  self.ocursor = self.olen + 1
  return self
end



--- Moves the cursor to the position given by the index.
-- Cursor position indexes range from 1 to `len + 1`, where `len` is the length of the string in characters.
-- Negative indexes are counted from the end backwards, so `-1` is the same as `goto_end`.
-- If the index is out of bounds, it will move the cursor to the closest valid position.
-- @tparam number pos the position (in characters) to move the cursor to (0-based index)
-- @return self (for chaining)
function UTF8EditLine:goto_index(pos)
  pos = utils.resolve_index(pos, self.ilen + 1, 1)
  if pos < 0 then
    return self:goto_home()
  end

  if pos >= self.ilen + 1 then
    return self:goto_end()
  end

  local head = self.head.next
  local l = 1
  self.ocursor = 1
  while head do
    if l == pos then
      self.icursor = head
      return self
    end
    self.ocursor = self.ocursor + width.utf8cwidth(head.value or "")
    l = l + 1
    head = head.next
  end
  return self
end



--- Clears the input.
-- @return self (for chaining)
function UTF8EditLine:clear()
  self.head.next = self.tail
  self.tail.prev = self.head
  self.icursor = self.tail
  self.ocursor = 1
  self.ilen = 0
  self.olen = 0
  return self
end



--- Replaces the current input with a new string.
-- This function clears the current input and inserts the new string at the end.
-- The cursor will be at the end of the new string.
-- @tparam string s the new string to insert
-- @return self (for chaining)
function UTF8EditLine:replace(s)
  return self:clear():insert(s):goto_end()
end



--- Deletes all characters to the left of the current cursor position.
-- @return self (for chaining)
function UTF8EditLine:backspace_to_start()
  while self.icursor.prev ~= self.head do
    self:backspace()
  end
  return self
end



--- Deletes all characters to the right of the current cursor position.
-- @return self (for chaining)
function UTF8EditLine:delete_to_end()
  while self.icursor ~= self.tail do
    self:delete()
  end
  return self
end



--- Moves the cursor to the start of the current word. If already at start, moves to the start of the previous word.
-- This function moves the cursor left until it reaches the start of the previous word.
-- Words are defined by non-delimiter characters.
-- @tparam[opt=1] number n the number of words to move left
-- @return self (for chaining)
function UTF8EditLine:left_word(n)
  for _ = 1, n or 1 do
    while self.icursor.prev ~= self.head do
      if is_delimiter(self, self.icursor.prev) == false then
        break
      end
      self:left()
    end
    while self.icursor.prev ~= self.head do
      if is_delimiter(self, self.icursor.prev) then
        break
      end
      self:left()
    end
  end
  return self
end



--- Moves the cursor to the start of the next word.
-- This function moves the cursor right until it reaches the end of the next word.
-- Words are defined by non-delimiter characters.
-- @tparam[opt=1] number n the number of words to move left
-- @return self (for chaining)
function UTF8EditLine:right_word(n)
  for _ = 1, n or 1 do
    while self.icursor ~= self.tail do
      if is_delimiter(self, self.icursor) then
        break
      end
      self:right()
    end
    while self.icursor ~= self.tail do
      if not is_delimiter(self, self.icursor) then
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
function UTF8EditLine:backspace_word(n)
  for _ = 1, n or 1 do
    while self.icursor.prev ~= self.head do
      if is_delimiter(self, self.icursor.prev) == false then
        break
      end
      self:backspace()
    end
    while self.icursor.prev ~= self.head do
      if is_delimiter(self, self.icursor.prev) then
        break
      end
      self:backspace()
    end
  end
  return self
end



--- Delete until the end of the current word.
-- Words are defined by non-delimiter characters.
-- @tparam[opt=1] number n the number of words to move left
-- @return self (for chaining)
function UTF8EditLine:delete_word(n)
  for _ = 1, n or 1 do
    while self.icursor ~= self.tail do
      if is_delimiter(self, self.icursor) == false then
        break
      end
      self:delete()
    end
    while self.icursor ~= self.tail do
      if is_delimiter(self, self.icursor) then
        break
      end
      self:delete()
    end
  end
  return self
end



return UTF8EditLine
