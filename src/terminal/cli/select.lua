--- A single-choice interactive menu widget for CLI tools.
--
-- This module provides a simple way to create a menu with a list of choices,
-- allowing the user to navigate and select an option using keyboard input.
-- The menu is displayed in the terminal, and the user can use the arrow keys
-- to navigate through the options, or type to search for an option.
-- The selected option is highlighted, and the
-- user can confirm their choice by pressing Enter. Optionally the menu can also be
-- cancelled by pressing `<esc>` or `<ctrl+c>`.
--
-- NOTE: you MUST call `terminal.initialize` before calling this widget's `:run()` method.
--
-- *Usage:*
--     local menu = cli.Select{
--       prompt = "Select an option:",
--       choices = {
--         "Option 1",
--         "Option 2",
--         "Option 3"
--       },
--       default = 1,
--       cancellable = true
--     }
--
--     local selected_index, selected_value = menu()  -- invokes the 'run' method
--     print("Selected index: " .. selected_index)
--     print("Selected value: " .. selected_value)
-- @classmod cli.Select

local t = require("terminal")
local EditLine = require("terminal.editline")
local Sequence = require("terminal.sequence")
local utils = require("terminal.utils")

local Select = utils.class()





-- Key bindings
local keys = t.input.keymap.get_keys()
local ctrl_c = assert(t.input.keymap.get_raw_key("ctrl_c"))
local keymap = t.input.keymap.get_keymap({
  [ctrl_c] = keys.escape, -- remap Ctrl+C --> Esc
})



-- UI symbols (including trailing whitespace)
local filled_diamond = "◆ "
local diamond = "◇ "
local circle  = "○ "
local dot     = "● "
local pipe    = "│  "
local angle   = "└  "



--- Create a new Select instance.
-- @tparam table opts Options for the Select menu.
-- @tparam table opts.choices List of choices (strings) to display.
-- @tparam[opt=1] number opts.default Default choice index (1-based).
-- @tparam[opt="Select an option:"] string opts.prompt Prompt message to display.
-- @tparam[opt=false] boolean opts.cancellable Whether the menu can be cancelled (by pressing `<esc>` or `<ctrl+c>`).
-- @tparam[opt=false] boolean opts.clear Whether to clear the widget from screen after completion.
-- @tparam[opt=1.0] number opts.typeahead_delay Seconds of inactivity after which the typeahead search buffer resets.
-- @treturn Select A new Select instance.
-- @name cli.Select
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
  self.clear = not not opts.clear
  self.typeahead_delay = opts.typeahead_delay or 1.0

  self:template()
end



-- Allow instance to be called directly
function Select:__call()
  return self:run()
end



-- Build full UI sequence
function Select:template()
  local res = Sequence(
    function() return t.cursor.position.up_seq():rep(self:height()) end,
    function() return t.text.push_seq({ fg = "green" }) end,
    function() return self.completed and filled_diamond or diamond end,
    t.text.pop_seq,
    self.prompt,
    t.clear.eol_seq,
    "\n"
  )

  for i, option in ipairs(self.choices) do
    res = res + Sequence(
      i == #self.choices and angle or pipe,
      function() return i == self.selected and dot or circle end,
      function()
        local active = (not self.completed) and (i == self.selected)
        return t.text.push_seq({
          fg = active and "yellow" or "white",
          brightness = active and "normal" or "dim"
        })
      end,
      option,
      t.text.pop_seq,
      t.clear.eol_seq,
      "\n"
    )
  end

  self.__template = res
end



-- Read and normalize key input
function Select:readKey(timeout)
  local rawkey, keytype = t.input.readansi(timeout)
  return rawkey, keymap[rawkey] or rawkey, keytype
end



-- Find first choice whose prefix matches the current search buffer (case-insensitive).
-- Starts at self.selected (inclusive) and wraps around. Returns self.selected if no match.
function Select:_findMatch()
  local prefix = tostring(self._search):lower()

  if #prefix == 0 then
    return self.selected
  end

  local n = #self.choices
  for i = 0, n - 1 do
    local idx = (self.selected - 1 + i) % n + 1
    if self.choices[idx]:lower():sub(1, #prefix) == prefix then
      return idx
    end
  end

  return self.selected
end



-- Handle input loop and navigation
function Select:handleInput()
  self._search = EditLine{}

  local res1, res2
  while true do
    t.output.write(self.__template)

    local timeout = self._search:len_char() > 0 and self.typeahead_delay or math.huge
    local rawkey, keyName, keytype = self:readKey(timeout)

    if rawkey == nil then
      -- timeout (or error): reset search buffer
      self._search:clear()

    elseif keyName == keys.backspace or keyName == keys.del then
      -- backspace: trim search buffer if active, otherwise ignore
      if self._search:len_char() > 0 then
        self._search:backspace()
        self.selected = self:_findMatch()
      end

    elseif keytype == "char" then
      self._search:insert(rawkey)
      self.selected = self:_findMatch()

    elseif keyName == keys.up then
      self._search:clear()
      self.selected = math.max(1, self.selected - 1)

    elseif keyName == keys.down then
      self._search:clear()
      self.selected = math.min(#self.choices, self.selected + 1)

    elseif keyName == keys.escape and self.cancellable then
      self._search:clear()
      res1, res2 = nil, "cancelled"
      break

    elseif keyName == keys.enter then
      self._search:clear()
      res1 = self.selected
      self.completed = true
      t.output.write(self.__template)
      break
    end
  end
  return res1, res2
end



--- Returns the display height in rows.
-- @treturn number The height of the menu in rows.
function Select:height()

  if not self.widths then
    -- first call, so calculate display width
    self.widths = {}
    for i, txt in ipairs(self.choices) do
      self.widths[i] = t.text.width.utf8swidth(pipe .. circle .. txt)
    end
    self.widths[0] = t.text.width.utf8swidth(diamond .. self.prompt)
  end

  local _, cols = t.size()
  local rows = 0
  for i = 0, #self.choices do
    rows = rows + math.ceil(self.widths[i] / cols)
  end
  return rows
end



--- Clears the widget.
function Select:clear_widget()
  t.output.write(
    t.cursor.position.up_seq():rep(self:height()),
    (t.clear.eol_seq() .. "\n"):rep(self:height()),
    t.cursor.position.up_seq():rep(self:height())
  )
end



--- Prints a one-line summary of the prompt and selected response.
function Select:print_selection()
  t.output.write(
    t.text.push_seq({ fg = "green" }),
    filled_diamond,
    t.text.pop_seq(),
    self.prompt,
    " ",
    t.text.push_seq({ fg = "yellow", brightness = "dim" }),
    self.choices[self.selected],
    t.text.pop_seq(),
    t.clear.eol_seq(),
    "\n"
  )
end



--- Set the current selection index.
-- @tparam number idx The index to set as the current selection (1-based).
function Select:set_selection(idx)
  assert(type(idx) == "number", "selection index must be a number")
  assert(idx >= 1 and idx <= #self.choices, "selection index out of range")
  self.selected = idx
end



--- Executes the widget.
-- @treturn[1] number The index of the selected choice (1-based)
-- @treturn[1] string The selected choice
-- @treturn[2] nil If cancelled
-- @treturn[2] string Error string `"cancelled"` if cancelled.
function Select:run()
  self.completed = false  -- reset completed state in case of multiple runs

  -- Reserve space for rendering
  t.output.write(("\n"):rep(#self.choices + 1))
  t.cursor.visible.push(false)

  local idx, err = self:handleInput()

  if self.clear then
    self:clear_widget()
  end

  t.cursor.visible.pop()

  if not idx then
    return nil, err
  end

  return idx, self.choices[idx]
end



return Select
