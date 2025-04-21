--- terminal.cli.select
-- A single-choice interactive menu widget for CLI tools.
--
-- This module provides a simple way to create a menu with a list of choices,
-- allowing the user to navigate and select an option using keyboard input.
-- The menu is displayed in the terminal, and the user can use the arrow keys
-- to navigate through the options. The selected option is highlighted, and the
-- user can confirm their choice by pressing Enter. Optionally he menu can also be
-- cancelled by pressing Escape or Ctrl+C.
-- @classmod Select

local t = require("terminal")
local Sequence = require("terminal.sequence")
local utils = require("terminal.utils")

local Select = utils.class()



-- Key bindings
local keys = t.input.keymap.get_keys()
local keymap = t.input.keymap.get_keymap({
  k = keys.up,    -- Vim-style up
  j = keys.down,  -- Vim-style down
  ctrl_c = keys.escape, -- Ctrl+C
})



-- UI symbols
local diamond = "◇"
local pipe = "│"
local circle = "○"
local dot = "●"



--- Initialize Select.
-- This method is invoked by calling on the class.
-- @tparam table opts Options for the Select menu.
-- @tparam table opts.choices List of choices (strings) to display.
-- @tparam[opt=1] number opts.default Default choice index (1-based).
-- @tparam[opt="Select an option:"] string opts.prompt Prompt message to display.
-- @tparam[opt=false] boolean opts.cancellable Whether the menu can be cancelled (by pressing `<esc>` or `<ctrl+c>`).
-- @treturn Select A new Select instance.
-- @usage
-- local menu = Select{   -- invokes the 'init' method
--   prompt = "Select an option:",
--   choices = {
--     "Option 1",
--     "Option 2",
--     "Option 3"
--   },
--   default = 1,
--   cancellable = true
-- }
--
-- local selected_index, selected_value = menu()  -- invokes the 'run' method
-- print("Selected index: " .. selected_index)
-- print("Selected value: " .. selected_value)
function Select:init(opts)
  assert(type(opts) == "table", "options must be a table")
  assert(type(opts.choices) == "table", "choices must be a table")
  assert(#opts.choices > 0, "choices must not be empty")
  for _, val in ipairs(opts.choices) do
    assert(type(val) == "string", "each choice must be a string")
  end
  self.choices = opts.choices

  self.default = opts.default or 1
  assert(type(self.default) == "number", "default must be a number")
  assert(self.default >= 1 and self.default <= #self.choices, "default out of range")

  self.prompt = opts.prompt or "Select an option:"
  assert(type(self.prompt) == "string", "prompt must be a string")

  self.selected = self.default
  self.cancellable = not not opts.cancellable

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
  return key, keymap[key] or key
end



-- Handle input loop and navigation
function Select:handleInput()
  local res1, res2
  while true do
    t.output.write(self.__template)

    local _, keyName = self:readKey()

    if keyName == keys.up then
      self.selected = math.max(1, self.selected - 1)

    elseif keyName == keys.down then
      self.selected = math.min(#self.choices, self.selected + 1)

    elseif keyName == keys.escape and self.cancellable then
      res1, res2 = nil, "cancelled"
      break

    elseif keyName == keys.enter then
      res1 = self.selected
      break
    end
  end
  return res1, res2
end



--- Executes the menu.
-- If necessary it initializes the terminal first.
-- It also handles the cleanup of the terminal state after the menu is closed.
-- @treturn number|nil The index of the selected choice (1-based) or nil if cancelled.
-- @treturn string|err The selected choice or `"cancelled"` if cancelled.
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
