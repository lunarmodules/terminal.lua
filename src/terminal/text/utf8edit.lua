local M = {}
package.loaded["terminal.text.utf8edit"] = M -- Register the module early to avoid circular dependencies

local utils = require("terminal.utils")
local width = require("terminal.text.width")
local utf8 = require("utf8") -- explicit lua-utf8 library call, for <= Lua 5.3 compatibility

local UTF8EditLine = utils.class()

do
  function UTF8EditLine:__tostring()
      local head = self.head
      local res = {}
      while head do
        res[#res + 1] = head.value or ""
        head = head.next
      end
      return table.concat(res)
  end

  -- Parses a UTF8 string into list of individual characters.
  -- @tparam string s the UTF8 string to parse
  -- @treturn table the list of characters
  function UTF8EditLine:init(s)
    self.icursor = {}          -- tracking the cursor internally (inside the table)
    self.ocursor = 1           -- tracking the cursor externally (as displayed)
    self.ilen = 0              -- tracking the length internally (# of utf8 characters)
    self.olen = 0              -- tracking the length externally (# of displayed columns)
    self.head = {}              -- start of the list
    self.tail = self.icursor -- prepare linked list
    self.tail.prev = self.head
    self.head.next = self.tail
    if s and #s ~= 0 then
      for _, c in utf8.codes(s) do
        self:add(utf8.char(c))
      end
    end
  end

  function UTF8EditLine:add(c) -- add to string at index
    if c == nil then return end
    local node = { value = c, next = self.icursor, prev = self.icursor.prev }
    self.icursor.prev.next = node
    self.icursor.prev = node
    self.ilen = self.ilen + 1
    self.olen = self.olen + width.utf8cwidth(c)
    self.ocursor = self.ocursor + width.utf8cwidth(c)
  end

  function UTF8EditLine:backspace() -- backspace at cursor
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

  function UTF8EditLine:left()
    if self.icursor.prev == self.head then return end
    self.icursor = self.icursor.prev
    self.ocursor = self.ocursor - (self.icursor.value and width.utf8cwidth(self.icursor.value) or 1)
  end

  function UTF8EditLine:right()
    if self.icursor == self.tail then return end
    self.ocursor = self.ocursor + (self.icursor.value and width.utf8cwidth(self.icursor.value) or 1)
    self.icursor = self.icursor.next
  end

  function UTF8EditLine:delete()
    if self.icursor == self.tail then return end
    self:right()
    self:backspace()
  end
end

M.UTF8EditLine = UTF8EditLine

return M
