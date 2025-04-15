-- terminal.cli.select
-- A single-choice interactive menu widget for CLI tools.
local t = require("terminal")
local Sequence = require("terminal.sequence")
local utils = require("terminal.utils")

local Select = utils.class()

-- Key bindings
local key_names = {
  ["\27[A"] = "up",    -- Up arrow
  ["k"]     = "up",    -- Vim-style up
  ["\27[B"] = "down",  -- Down arrow
  ["j"]     = "down",  -- Vim-style down
  ["\r"]    = "enter", -- Carriage return (Enter)
  ["\n"]    = "enter", -- Newline (Enter)
  ["\27"]   = "esc",   -- Escape
}

-- UI symbols
local diamond = "◇"
local pipe = "│"
local circle = "○"
local dot = "●"

-- Initialize menu
function Select:init()
  assert(type(self.choices) == "table", "choices must be a table")
  assert(#self.choices > 0, "choices must not be empty")
  for _, val in ipairs(self.choices) do
    assert(type(val) == "string", "each choice must be a string")
  end

  self.default = self.default or 1
  assert(type(self.default) == "number", "default must be a number")
  assert(self.default >= 1 and self.default <= #self.choices, "default out of range")

  self.selected = self.default
  self.prompt = self.prompt or "Select an option:"
  self.cancellable = not not self.cancellable

  self:template()
end

-- Allow instance to be called directly
function Select:__call()
  return self:run()
end

-- Build full UI sequence
function Select:template()
  local res = Sequence(
    t.cursor.position.up_seq():rep(#self.choices + 1),
    function() return t.text.stack.push_seq({ fg = "green" }) end,
    diamond,
    t.text.stack.pop_seq,
    " ",
    self.prompt,
    t.clear.eol_seq,
    "\n"
  )

  for i, option in ipairs(self.choices) do
    res = res + Sequence(
      pipe, "   ",
      function() return i == self.selected and dot or circle end,
      " ",
      function()
        return t.text.stack.push_seq({
          fg = (i == self.selected) and "yellow" or "white",
          brightness = (i == self.selected) and "normal" or "dim"
        })
      end,
      option,
      t.text.stack.pop_seq,
      t.clear.eol_seq,
      "\n"
    )
  end

  self.__template = res
end

-- Read and normalize key input
function Select:readKey()
  local key = t.input.readansi(math.huge)
  return key, key_names[key] or key
end

-- Handle input loop and navigation
function Select:handleInput()
  local res1, res2
  while true do
    t.output.write(self.__template)

    local _, keyName = self:readKey()

    if keyName == "up" then
      self.selected = math.max(1, self.selected - 1)
    elseif keyName == "down" then
      self.selected = math.min(#self.choices, self.selected + 1)
    elseif keyName == "esc" and self.cancellable then
      res1, res2 = nil, "cancelled"
      break
    elseif keyName == "enter" then
      res1 = self.selected
      break
    end
  end
  return res1, res2
end

-- Public API to run the menu
function Select:run()
  local revert
  if not t.ready() then
    t.initialize()
    revert = true
  end

  -- Reserve space for rendering
  t.output.write(("\n"):rep(#self.choices + 1))
  t.cursor.visible.stack.push(false)

  local idx, err = self:handleInput()

  t.cursor.visible.stack.pop()
  if revert then t.shutdown() end

  if not idx then
    return nil, err
  end

  return idx, self.choices[idx]
end

return Select
