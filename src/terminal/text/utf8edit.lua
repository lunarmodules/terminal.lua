--- UTF8 based editline class.
--
-- This class handles a UTF8 string with operations, and cursor tracking.
--
-- @classmod text.utf8edit
-- @usage
-- local Utf8edit = require("terminal.text.utf8edit")
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
-- line:add("!")
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



--- Creates a new `utf8edit` instance.
-- The cursor position will be at the end of the string.
-- @tparam[opt=""] string s the UTF8 string to parse
-- @treturn table the list of characters
function UTF8EditLine:init(s)
  self.icursor = {}          -- tracking the cursor internally (utf8 characters)
  self.ocursor = 1           -- tracking the cursor externally (columns)
  self.ilen = 0              -- tracking the length internally (# of utf8 characters)
  self.olen = 0              -- tracking the length externally (# of displayed columns)
  self.head = {}             -- start of the list
  self.tail = self.icursor   -- prepare linked list
  self.tail.prev = self.head
  self.head.next = self.tail
  for _, c in utf8.codes(s or "") do
    self:add(utf8.char(c))
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



--- Inserts a character at the current cursor position.
-- @tparam string c the character to insert
-- @return nothing
function UTF8EditLine:add(c) -- add to string at index
  -- TODO: rename to "insert" and allow multi character strings to be added
  if c == nil then return end
  local node = { value = c, next = self.icursor, prev = self.icursor.prev }
  self.icursor.prev.next = node
  self.icursor.prev = node
  self.ilen = self.ilen + 1
  self.olen = self.olen + width.utf8cwidth(c)
  self.ocursor = self.ocursor + width.utf8cwidth(c)
end



--- Deletes the character left of the current cursor position.
-- If/once the cursor is at the start of the string, it does nothing.
function UTF8EditLine:backspace(n)
  for _ = 1, n or 1 do
    if self.icursor.prev == self.head then return end
    local prev = self.icursor.prev.prev or self.head
    local next = self.icursor
    local c = self.icursor.prev.value
    prev.next = next
    next.prev = prev
    self.ilen = self.ilen - 1
    self.olen = self.olen - width.utf8cwidth(c)
    self.ocursor = self.ocursor - width.utf8cwidth(c)
  end
end



--- Moves the cursor to the left.
-- This function moves the cursor left by `n` characters. It will not move the cursor
-- past the start of the string (no error will be raised).
-- @tparam[opt=1] number n the number of characters to move left
function UTF8EditLine:left(n)
  for _ = 1, n or 1 do
    if self.icursor.prev == self.head then return end
    self.icursor = self.icursor.prev
    self.ocursor = self.ocursor - (self.icursor.value and width.utf8cwidth(self.icursor.value) or 1)
  end
end



--- Moves the cursor to the right.
-- This function moves the cursor right by `n` characters. It will not move the cursor
-- past the end of the string (no error will be raised).
-- @tparam[opt=1] number n the number of characters to move right
function UTF8EditLine:right(n)
  for _ = 1, n or 1 do
    if self.icursor == self.tail then return end
    self.ocursor = self.ocursor + (self.icursor.value and width.utf8cwidth(self.icursor.value) or 1)
    self.icursor = self.icursor.next
  end
end



--- Deletes the character at the current cursor position.
-- If/once the cursor is at the end of the string, it does nothing.
-- @tparam[opt=1] number n the number of characters to delete
function UTF8EditLine:delete(n)
  for _ = 1, n or 1 do
    if self.icursor == self.tail then return end
    self:right()
    self:backspace()
  end
end



return UTF8EditLine
