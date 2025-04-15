-- This example shows how to create a CLI based widget for user input.
-- It presents the user with a list of options, that can be selected using
-- the arrow keys, and by pressing enter.
--
-- What it does well:
-- - only uses relative positioning, such that the user scrolling the screen up/down
--   does not affect the widget
-- - positions the cursor statically below the widget, because resizing the terminal
--   can have a different effect on the line where the cursor is.
-- - entire widget is drawn from a single (dynamic) sequence, simplifying the remainder of the code
-- - ends each line with a `clear.eol()` call, such that it cleans up after a resize/redraw.
-- - the sequence ansures the cursor returns to the original position. Such that writing the
--   sequence again just works.
--
-- To be improved:
-- - moving cursor up/down is relative, but if the prompt or an option rolls-over to the next line
--   we'd need an extra up/down to get the cursor back to the right position.
-- - the rolling-over needs to be dynamic, since the user might also resize the screen.
-- - when the user resizes, it should redraw, instead of waiting for a key-press
-- - it uses its own class/instance mechanism, which should be externalised

local t = require "terminal"
local Sequence = require("terminal.sequence")



-- Key bindings for arrow keys, 'j', 'k', and Enter.
local key_names = {
  ["\27[A"] = "up",  -- Up arrow key
  ["k"] = "up",      -- 'k' key
  ["\27[B"] = "down",-- Down arrow key
  ["j"] = "down",    -- 'j' key
  ["\r"] = "enter",  -- Carriage return (Enter)
  ["\n"] = "enter",  -- Newline (Enter)
  ["\27"] = "esc",   -- Escape key
}

local diamond      = "◇"
local pipe         = "│"
local circle       = "○"
local dot          = "●"



-- define the class
local IMenu = {}
IMenu.__index = IMenu



function IMenu:__call()
  -- This method is called when calling on an INSTANCE
  -- run the instance
  return self:run()
end



setmetatable(IMenu, {
  -- This method is called when calling on the CLASS
  -- create an instance
  __call = function(cls, options)
    local self = setmetatable({}, cls)

    -- validate options
    assert(type(options) == "table", "options must be a table, got " .. type(options))
    assert(type(options.choices) == "table", "options.choices must be a table, got " .. type(options.choices))
    assert(#options.choices > 0, "options.choices must not be empty")
    for _, val in pairs(options.choices) do
      if type(val) ~= "string" then
        return nil, "expected option.choices entries to be a string but got" .. type(val) .. " instead"
      end
    end

    local default = options.default or 1
    assert(type(default) == "number", "options.default must be a number, got " .. type(default))
    assert(default >= 1 and default <= #options.choices, "options.default out of range")

    local prompt = options.prompt or "Select an option:"
    assert(type(prompt) == "string", "options.prompt must be a string, got " .. type(prompt))

    self._choices = options.choices
    self.selected = default
    self.prompt = prompt
    self.cancellable = not not options.cancellable
    self:template() -- build the template
    return self
  end,
})



-- build the entire prompt as a single sequence
function IMenu:template()
  -- display the prompt
  local res = Sequence(
    t.cursor.position.up_seq():rep(#self._choices + 1), -- move cursor up
    function() return t.text.stack.push_seq({fg = "green"}) end,
    diamond,
    t.text.stack.pop_seq,
    " ",
    self.prompt,
    t.clear.eol_seq,
    "\n"
  )
  -- add options, dynamically coloring the selected one
  for i, option in pairs(self._choices) do
    res = res + Sequence(
      pipe,
      "   ",
      function() return i == self.selected and dot or circle end,
      " ",
      function()
        if i == self.selected then
          return t.text.stack.push_seq({fg = "yellow", brightness = "normal"})
        else
          return t.text.stack.push_seq({fg = "white", brightness = "dim"})
        end
      end,
      option,
      t.text.stack.pop_seq,
      t.clear.eol_seq,
      "\n"
    )
  end

  self.__template = res
end



function IMenu:readKey()
  local key = t.input.readansi(math.huge)
  return key, key_names[key] or key
end



function IMenu:handleInput()
  local res1, res2
  while true do
    t.output.write(self.__template)                 -- Write the template to the screen.

    local  _, keyName = self:readKey()

    if keyName == "up" then
      self.selected = math.max(1, self.selected - 1)

    elseif keyName == "down" then
      self.selected = math.min(#self._choices, self.selected + 1)

    elseif keyName == "esc" and self.cancellable then
      res1 = nil
      res2 = "cancelled"
      break

    elseif keyName == "enter" then
      res1 = self.selected
      break
    end
  end

  return res1, res2
end



-- Runs the prompt and returns the selected option index.
function IMenu:run()
  assert(self ~= IMenu, "IMenu is a class, not an instance")
  local revert
  if not t.ready() then -- initialize only if not done already
    t.initialize()
    revert = true
  end

  -- make room for our widget
  t.output.write(("\n"):rep(#self._choices + 1))

  t.cursor.visible.stack.push(false)
  local idx, err = self:handleInput()
  t.cursor.visible.stack.pop()

  if revert then
    t.shutdown()
  end

  if not idx then
    return nil, err
  end

  return idx, self._choices[idx]
end



-- =================================================
--   End of the class definition
-- =================================================

t.initialize{
  disable_sigint = true,
  autotermrestore = true,
}

-- Example usage
local myMenu = IMenu{
  prompt = "Select a Lua version:",
  choices = { "Lua 5.1", "Lua 5.2", "LuaJIT", "Lua 5.3", "Lua 5.4", "Teal" },
  default = 5,          -- default to Lua 5.4
  cancellable = true,   -- press <esc> to cancel
}

local idx, option = myMenu()
print("selected: " .. tostring(idx) .. ", option: " .. option)

